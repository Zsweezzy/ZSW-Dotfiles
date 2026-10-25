// AudioFlyout.qml — click flyout for the audio pill.
//
// Sections:
//   Output devices   click a row → Pipewire.preferredDefaultAudioSink
//   Phone audio      the bluetooth phone streaming into this PC, as a switch.
//                    Always drawn; greyed out with a hover explanation when no
//                    phone is connected. Pairing itself is done in the settings
//                    flyout's bluetooth panel.
//   Input devices    click a row → Pipewire.preferredDefaultAudioSource
//                    the active input device also carries a volume slider
//                    + mute, same as the active output device above
//                    every input row also carries a headphones glyph that
//                    loops that mic into the current output — "listen to mic"
//   Applications     per-playback-app volume slider + mute toggle
//   Advanced         bottom drawer: the switch that lifts the app sliders to
//                    150% instead of 100%
//
// Uses the native Quickshell Pipewire service (same source as Audio.qml).
// Device/app lists come from Pipewire.nodes — every node carries isSink/isStream
// flags (no isSource helper): "output device" = isSink, "app" = isSink + isStream,
// "input device" = !isSink (duplex cards are isSink, kept only when they are the
// current default source). `grabFocus` makes the xdg_popup dismiss on any outside
// click (visible flips to false automatically).
//
// CRITICAL: nodes are only bound to PipeWire while something holds a reference
// (PwObjectTracker -> refcount). Unbound nodes report zero/stale audio state and
// volume writes are dropped ("Tried to change node volumes ... not bound"). The
// tracker below keeps every listed app/device node bound so sliders work.
import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Services.Pipewire

PopupWindow {
    id: root

    visible: false
    grabFocus: true
    color: "transparent"

    readonly property real gap: 6      // transparent strip, like Tooltip.qml
    readonly property real padH: 16
    readonly property real padV: 12
    readonly property int rowHeight: 36

    // 392, not the 360 it was: the device rows gained a percentage readout, and
    // at 360 the device name was left with 98px — enough for "USB Audio" and
    // nothing else, so the longest names all elided to the same stub. The
    // panel is anchored to the pill, not sized by the bar, so widening it
    // costs nothing but the room it takes on screen.
    implicitWidth: 392
    implicitHeight: box.height + root.gap

    // ---------------- lists ----------------
    function correctType(node, isSink) {
        return !!node && node.isSink === isSink && !!node.audio
    }
    function outputDevicesList() {
        return Pipewire.nodes.values.filter(n => root.correctType(n, true) && !n.isStream)
    }
    // Inputs are `!isSink` audio nodes (alsa_input.* etc.). Duplex cards also
    // satisfy isSink, so keep them here only when they are the current default
    // source — otherwise they would never show up as input devices.
    //
    // The active source is kept unconditionally, `!n.audio` included. Quickshell
    // builds a node's audio interface from an exact match on media.class, so a
    // driver that names its source `Audio/Source/Virtual` (linux-soundboard)
    // gets no interface at all — and dropping it for that reason hid the one
    // mic you are actually recording from. WpAudio below still drives it.
    function inputDevicesList() {
        return Pipewire.nodes.values.filter(n => {
            if (!n || n.isStream) return false
            if (n === Pipewire.defaultAudioSource) return true
            if (!n.audio) return false
            return !n.isSink
        })
    }
    function appNodes(isSink) {
        return Pipewire.nodes.values.filter(n => root.correctType(n, isSink) && n.isStream)
    }
    readonly property var outputDevices: root.outputDevicesList()
    readonly property var inputDevices: root.inputDevicesList()
    readonly property var apps: root.appNodes(true)
    /// every node the flyout manages — kept ref'd/bound by the tracker below
    readonly property var trackedNodes: root.outputDevices.concat(root.inputDevices, root.apps)

    // ---------------- devices with no native audio interface ----------------
    /// Volume/mute for a device Quickshell gave no audio interface, addressed
    /// through wpctl instead. It presents the same `volume` / `muted` surface a
    /// PwNodeAudioIface does, so the rows below cannot tell the two apart.
    ///
    /// This is not hypothetical: a node's `media.class` is matched EXACTLY
    /// against "Audio/Source" / "Audio/Sink" / "Audio/Duplex" /
    /// "Stream/Output/Audio" / "Stream/Input/Audio" when Quickshell decides
    /// whether to build it an audio interface (PwNode::initProps), and anything
    /// else gets none. "Audio/Source/Virtual" — the linux-soundboard mic, i.e.
    /// this machine's default source — is one of those. No interface means no
    /// `volume` property, so there is nothing for a slider to bind to.
    ///
    /// wpctl addresses a node by its numeric PipeWire id and does not care
    /// about media.class at all. It is also the only way to READ back state
    /// here: there is no native signal to subscribe to, so the value is polled.
    component WpAudio: Item {
        id: wpa

        /// the PwNode this stands in for, or null
        property var node: null
        /// 0.0 - 1.0, as wpctl reports it
        property real volume: 0
        property bool muted: false
        /// One flag per polled property, NOT one shared flag: the poll absorbs
        /// both in the same tick, and each assignment synchronously runs its
        /// own onChanged handler — so a single flag would be consumed by the
        /// first one and the second would write the poll's own value straight
        /// back out as if the user had moved a control.
        ///
        /// ONLY absorbX arms these, and only when the value actually moved —
        /// see absorbVolume. writeVolume deliberately does NOT arm them: the
        /// property already holds the value just written, so the next poll
        /// finds it unchanged and never needs suppressing, and an arm here
        /// would outlive that poll and eat the following real drag.
        property bool applyingVolume: false
        property bool applyingMuted: false

        /// wpctl takes the numeric PipeWire id; a node NAME is rejected with
        /// "Error: '<name>' is not a valid number". `id` is readonly on PwNode
        /// and is exactly the number `wpctl status` prints.
        readonly property int id: wpa.node ? wpa.node.id : -1

        function writeVolume(v) {
            if (wpa.id < 0) return
            Quickshell.execDetached(["wpctl", "set-volume",
                                     String(wpa.id), Math.max(0, v).toFixed(3)])
        }
        function writeMute(on) {
            if (wpa.id < 0) return
            Quickshell.execDetached(["wpctl", "set-mute", String(wpa.id), on ? "1" : "0"])
        }

        /// Absorb a polled value WITHOUT writing it straight back out.
        ///
        /// The `if (same) return` guard is load-bearing, not an optimisation:
        /// QML fires NO onChanged when a property is assigned its current value,
        /// so arming the suppression flag and then assigning an unchanged
        /// number leaves the flag armed forever — and the next real user write
        /// is eaten as if it were an echo of the poll. Measured: a source
        /// polled every 400ms whose volume stopped at 0.82 ignored every
        /// subsequent drag because of exactly this.
        /// The pendingVolume guard is the drag twin: while a debounced write is
        /// armed, a poll echo of the value BEFORE the write landed must not
        /// pull the slider back down mid-drag.
        function absorbVolume(v) {
            if (wpa.pendingVolume >= 0) return
            if (Math.abs(wpa.volume - v) < 0.001) return
            wpa.applyingVolume = true
            wpa.volume = v
        }
        function absorbMuted(m) {
            if (wpa.muted === m) return
            wpa.applyingMuted = true
            wpa.muted = m
        }

        /// Reads come as two separate one-shot probes, each addressing the node
        /// the way its tool wants it: wpctl by numeric id, pactl by NAME. The
        /// name is passed as a full argv element of `pactl` — never spliced
        /// into a shell string — so a hostile node name (a stream called
        /// `x; touch /tmp/pwn` or `$(...)` or with backticks) cannot escape
        /// into a command. The old single `sh -c` line concatenated the name
        /// into script text and ran it, which EXECUTED it: measured PWNED for
        /// `$(...)`, backticks, `;` and `'` payloads. Two probes also pick the
        /// right read from isSink with no guessing fallback.
        Poll {
            id: probe
            interval: 400
            // No id means nothing to read: park instead of spawning `sh`
            // five times a second to run nothing.
            active: wpa.id >= 0
            command: ["wpctl", "get-volume", String(wpa.id)]
            onResult: output => {
                const m = String(output).match(/Volume:\s*([0-9.]+)/)
                if (m) wpa.absorbVolume(parseFloat(m[1]))
            }
        }
        Poll {
            id: muteProbe
            interval: 400
            active: wpa.id >= 0 && !!wpa.node
            command: ["pactl",
                      wpa.node && wpa.node.isSink ? "get-sink-mute" : "get-source-mute",
                      wpa.node ? String(wpa.node.name) : ""]
            onResult: output => wpa.absorbMuted(/Mute:\s*yes/.test(String(output)))
        }

        /// A drag on a slider fires onVolumeChanged once per tick and spawns
        /// one wpctl per tick; the timer collapses a drag into a single write
        /// of the last value it reached. Poll echoes never touch this path —
        /// absorbVolume arms `applying`, which consumes them below.
        property real pendingVolume: -1
        Timer {
            id: writeDebounce
            interval: 120
            onTriggered: {
                if (wpa.pendingVolume >= 0) {
                    wpa.writeVolume(wpa.pendingVolume)
                    wpa.pendingVolume = -1
                }
            }
        }

        onVolumeChanged: if (wpa.applyingVolume) wpa.applyingVolume = false
                         else {
                             wpa.pendingVolume = wpa.volume
                             writeDebounce.restart()
                         }
        onMutedChanged: if (wpa.applyingMuted) wpa.applyingMuted = false
                        else wpa.writeMute(wpa.muted)
    }

    /// The two devices that can be controlled: the active output and the active
    /// input. Only these carry a slider, so only these need a fallback — and
    /// `!n.audio` is part of the lookup, because a device that HAS a native
    /// interface is driven through it, and standing a poll (a `sh` every 400ms)
    /// up for a node this will never be asked about is pure waste.
    WpAudio {
        id: wpSink
        node: root.outputDevices.find(n => !n.audio
                                     && n === Pipewire.defaultAudioSink) || null
    }
    WpAudio {
        id: wpSource
        node: root.inputDevices.find(n => !n.audio
                                     && n === Pipewire.defaultAudioSource) || null
    }

    /// The object a device row should control: the node's own interface when it
    /// has one, the wpctl stand-in when it does not, null when there is nothing
    /// to control. This is the single point where the two paths are chosen.
    function audioFor(node, asInput) {
        if (!node) return null
        if (node.audio) return node.audio
        const fb = asInput ? wpSource : wpSink
        return fb.node === node ? fb : null
    }

    function friendlyName(node) {
        // The phone's own name first: a bluez node is called
        // `bluez5.AA_BB_CC_DD_EE_FF_A2DP_SINK`, and the driver already knows
        // the thing on the other end is called "Pixel 8".
        return (node.properties["api.bluez5.device"]
                || node.properties["application.name"]
                || node.description || node.nickname || node.name || "Unknown")
    }

    function setDefault(node, asInput) {
        if (asInput) Pipewire.preferredDefaultAudioSource = node
        else Pipewire.preferredDefaultAudioSink = node
    }

    // ---------------- per-app routing ----------------
    // pactl is the only way to move a running app's stream to another device
    // (PipeWire alone cannot retarget a sink-input), so the MOVE drawer reads
    // pactl's JSON state while it is open: sink-inputs map to apps by
    // `properties.node.name` (PwNode.name) — pactl 17 has no node.id to match
    // on — and each sink-input's `sink` field is the numeric index of the
    // sink it currently plays through, looked up in the sink list. Nothing
    // here puts a name into a shell string: every pactl argument is its own
    // argv element, the same rule as the WpAudio probes.
    /// the app whose MOVE drawer is open, or null
    property var routeFor: null
    /// pactl sink-inputs: [{index, sink, properties.node.name}]
    property var routeStreams: []
    /// pactl sinks: [{index, name, description}]
    property var routeTargets: []
    /// the drawer polls only while some app's MOVE view is open; closed, a
    /// pactl every 1.5s is pure waste
    Poll {
        id: streamProbe
        interval: 1500
        active: !!root.routeFor
        command: ["pactl", "--format=json", "list", "sink-inputs"]
        // `active` gates the loop, but Poll runs one initial probe at load no
        // matter what — ignore it while no drawer is open so a stale snapshot
        // never sits in routeStreams. The parse depends on pactl 17 emitting
        // the whole array as ONE line: SplitParser fires per line, and any
        // multi-line format would fail the parse and degrade to "not playing"
        // instead of crashing.
        onResult: output => {
            if (!root.routeFor) return
            try {
                const parsed = JSON.parse(String(output))
                if (JSON.stringify(parsed) !== JSON.stringify(root.routeStreams))
                    root.routeStreams = parsed
            } catch (err) { root.routeStreams = [] }
        }
    }
    Poll {
        id: targetProbe
        interval: 1500
        active: !!root.routeFor
        command: ["pactl", "--format=json", "list", "sinks"]
        onResult: output => {
            if (!root.routeFor) return
            try {
                const parsed = JSON.parse(String(output))
                if (JSON.stringify(parsed) !== JSON.stringify(root.routeTargets))
                    root.routeTargets = parsed
            } catch (err) { root.routeTargets = [] }
        }
    }
    /// drop the open drawer when its app's stream disappears
    onAppsChanged: if (root.routeFor && !root.apps.includes(root.routeFor)) root.routeFor = null
    /// the sink-input pactl knows for this app, or null
    function sinkInputFor(app) {
        if (!app || !app.name) return null
        return root.routeStreams.find(s => s && s.properties
                                          && s.properties["node.name"] === app.name) || null
    }
    /// the sink this app's stream currently plays through, or null
    function routeDeviceFor(app) {
        const si = root.sinkInputFor(app)
        if (!si || si.sink === undefined) return null
        return root.routeTargets.find(t => t && t.index === si.sink) || null
    }
    /// a sink's human name (pactl's description), like the device rows use
    function friendlyTarget(target) {
        return target ? (target.description || target.name || "Unknown") : "Unknown"
    }
    function moveApp(app, target) {
        if (!target || !app || !app.name) return
        // One app can have several sink-inputs under the same node.name (four
        // Firefox streams are all "Firefox"); move every matching stream or
        // the others would stay on the old device. Argv elements only.
        const name = app.name
        for (const si of root.routeStreams) {
            if (si && si.properties && si.properties["node.name"] === name) {
                Quickshell.execDetached(["pactl", "move-sink-input",
                                         String(si.index), String(target.name)])
            }
        }
    }

    // ---------------- mic monitoring ----------------
    // "Listen to this mic" is not something PipeWire puts on the node — it is a
    // loopback the pulse layer owns. One module-loopback per source is loaded
    // into pipewire-pulse, so the routing outlives a config reload: this panel
    // remembers nothing, it reads the loaded modules back. No `sink=` is passed,
    // so the loopback follows the default output rather than being pinned to
    // whatever was default when it was switched on. latency_msec=1 because the
    // pulse default (~200ms) is audible as a slap-back echo when you monitor
    // yourself.
    //
    // `unload-module` addresses a module by its numeric index, and the JSON
    // form of `list modules` carries no index (only `pactl list modules short`
    // prints it) — so the probe reads the short form and pairs each loopback's
    // index with the source named in its argument. The argument is a module
    // loopback's own (`source=X sink=Y latency_msec=1`), never a newline, so a
    // line-per-module grep is exact. The pipeline is a fixed string: no node
    // name is ever spliced into it, the same rule the WpAudio probes and
    // moveApp follow.
    /// source name -> module index, for every loaded module-loopback
    property var listenMods: ({})
    Poll {
        id: listenProbe
        interval: 1000
        // Only while the panel is open: nothing on screen reads it otherwise.
        // Poll fires once at load regardless, which just seeds the real state.
        active: root.visible
        command: ["sh", "-c",
                  "pactl list modules short | grep module-loopback | tr \"\\n\" \";\""]
        onResult: output => {
            const mods = {}
            for (const line of String(output).split(";")) {
                const f = line.split("\t")
                if (f.length < 3 || f[1] !== "module-loopback") continue
                const m = f[2].match(/source=(\S+)/)
                if (m) mods[m[1]] = parseInt(f[0])
            }
            root.listenMods = mods
        }
    }
    function isListening(node) {
        return !!node && node.name !== undefined
                && root.listenMods[node.name] !== undefined
    }
    function toggleListen(node) {
        if (!node || !node.name) return
        const idx = root.listenMods[node.name]
        // Argv elements only — a hostile node name cannot reach a shell.
        if (idx !== undefined)
            Quickshell.execDetached(["pactl", "unload-module", String(idx)])
        else
            Quickshell.execDetached(["pactl", "load-module", "module-loopback",
                                     "source=" + node.name, "latency_msec=1"])
        // Show the new state without waiting out the whole interval.
        listenProbe.refresh()
    }

    // ---------------- window / anchoring ----------------
    PwObjectTracker {
        objects: root.trackedNodes
    }

    function toggleFor(item) {
        root.anchor.item = item
        root.anchor.edges = Edges.Bottom
        root.anchor.gravity = Edges.Bottom
        root.visible = !root.visible
    }

    // ---------------- overboost ----------------
    // PipeWire takes a volume above 1.0 — that is exactly what "volume over
    // 100%" means in pavucontrol — and these sliders hand the number straight to
    // it. It is off by default because a boosted stream clips on its loud parts,
    // so it has to be asked for rather than reached by accident. The flag lives
    // in AudioStates (not here) because the bar wheel reads the same ceiling
    // and both must agree after a config reload.
    /// whether the ADVANCED drawer at the bottom of the panel is open
    property bool advanced: false
    /// slider ceiling: 150% with overboost on, the ordinary 100% without it.
    /// Switching it off does not pull anything already above 100% back down —
    /// it only stops the slider from going there.
    readonly property real maxVolume: AudioStates.overboost ? 1.5 : 1

    /// The on/off switch, same shape as the settings flyout's: a capsule track
    /// with a knob that slides, so the knob's side is the state and no
    /// "on"/"off" text is needed beside it.
    component Toggle: Item {
        id: sw
        property bool checked: false
        /// false = drawn dim, no pointer: a hand cursor over something that
        /// cannot be pressed is a small lie.
        property bool interactive: true
        property color accent: Tokyo.cyan
        signal toggled()
        implicitWidth: 34
        implicitHeight: 18

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(sw.accent.r, sw.accent.g, sw.accent.b,
                           sw.checked ? 0.30 : 0.10)
            border.color: sw.checked ? sw.accent : Tokyo.bgHighlight
            border.width: 1
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Rectangle {
            width: 12; height: 12; radius: 6
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? sw.accent : Tokyo.dim
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: sw.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (sw.interactive) sw.toggled()
        }
    }

    // ---------------- volume slider + mute (shared) ----------------
    // One definition for every slider in this panel, so the device rows and
    // the app rows cannot drift apart. `audio` is a PwAudioNode — pass null
    // and the control simply draws nothing rather than throwing.
    component VolumeSlider: Controls.Slider {
        id: vs
        /// what this slider drives: a PwNodeAudioIface, a WpAudio, or null.
        /// Assigning `.volume` works for the native one; for WpAudio the
        /// assignment is what triggers its onVolumeChanged push, which is
        /// suppressed for a poll echo by its own `applying` flag — so both
        /// paths are the same line of code.
        property var audio
        /// true = the phone shim channel: integer 0-100 and
        /// PhoneAudio.setVolume instead of a 0-1 audio object.
        property bool phoneLike: false
        height: 22
        from: 0
        to: vs.phoneLike ? 100 : root.maxVolume
        stepSize: vs.phoneLike ? 1 : 0.01
        value: vs.phoneLike
               ? (PhoneAudio.volume >= 0 ? PhoneAudio.volume : 0)
               : (vs.audio ? vs.audio.volume : 0)
        onMoved: {
            if (vs.phoneLike) PhoneAudio.setVolume(vs.value)
            else if (vs.audio) vs.audio.volume = vs.value
        }

        background: Rectangle {
            y: vs.topPadding + vs.availableHeight / 2 - height / 2
            width: vs.availableWidth
            height: 4
            radius: 2
            color: Tokyo.bgHighlight
            Rectangle {
                width: vs.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: Tokyo.magenta
            }
        }
        handle: Rectangle {
            x: vs.leftPadding + vs.visualPosition * (vs.availableWidth - width)
            y: vs.topPadding + vs.availableHeight / 2 - height / 2
            width: 12
            height: 12
            radius: 6
            color: vs.pressed ? Tokyo.fg : Tokyo.pink
            border.color: Tokyo.bgDark
            border.width: 1
        }
    }

    /// The volume number, as a percentage. Extracted for the same reason as
    /// VolumeSlider and MuteGlyph: the device rows and the app rows would
    /// otherwise each carry their own copy and drift. Reaches past 100 when
    /// AMPLIFY is on, which is the point — that is what the slider is showing.
    component VolumePercent: Text {
        id: vp
        /// the PwAudioNode whose volume and mute state this reports; null
        /// renders nothing rather than throwing
        property var audio
        text: vp.audio ? Math.round(vp.audio.volume * 100) + "%" : ""
        // Recedes on mute, matching the app rows' long-standing behaviour —
        // the mute glyph beside it turns yellow and is what carries the state.
        color: vp.audio && vp.audio.muted ? Tokyo.bgHighlight : Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 12 }
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
    }

    /// The speaker/mic glyph, doubling as the mute switch. `audio` is null
    /// when there is nothing to control yet.
    component MuteGlyph: Item {
        id: mg
        /// the PwAudioNode whose muted flag this toggles
        property var audio
        /// true on an input device: a mute button drawn as a speaker is a small
        /// lie about which side of the pipe it controls, so inputs get the
        /// microphone glyphs (U+F130 / U+F131) instead.
        property bool isInput: false
        implicitWidth: 20
        implicitHeight: 18

        Text {
            anchors.centerIn: parent
            // \uF026 / \uF028 speaker off/on, \uF131 / \uF130 mic off/on.
            text: !mg.audio ? ""
                 : (mg.audio.muted ? (mg.isInput ? "" : "")
                                   : (mg.isInput ? "" : ""))
            color: mg.audio && mg.audio.muted ? Tokyo.yellow : Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: 11 }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !!mg.audio
            onClicked: if (mg.audio) mg.audio.muted = !mg.audio.muted
        }
    }

    Rectangle {
        id: box
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: content.implicitHeight + root.padV * 2
        color: Tokyo.bgDark
        radius: Tokyo.pillRadius
        border.color: Tokyo.bgHighlight
        border.width: 1

        Column {
            id: content
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: root.padH; rightMargin: root.padH; topMargin: root.padV
            }
            spacing: 2

            // ---------- output devices ----------
            Text {
                text: "OUTPUT DEVICES"
                font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                color: Tokyo.blue
                leftPadding: 4
                bottomPadding: 2
            }
            Rectangle {
                width: parent.width; height: 1
                color: Tokyo.bgHighlight
            }
            Repeater {
                model: root.outputDevices
                delegate: deviceRow
            }

            Item { height: 8 }

            // ---------- phone audio ----------
            // Backed by the standalone `phone-audio` app (phone → PC): this row
            // polls its status once a second through the PhoneAudio shim and
            // the switch calls `phone-audio toggle`. Always drawn, ready or
            // not. A switch that only appears once it works cannot be found,
            // and the one time you want it is the time you are looking for it
            // — so the row is permanent, greyed out when no phone is paired,
            // and hovering it shows the app's status/reason. The switch
            // itself is the same shape as the settings flyout's, so the two
            // menus do not disagree about what "on" looks like.
            Column {
                width: parent.width
                spacing: 2

                Text {
                    text: "PHONE AUDIO"
                    font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                    color: PhoneAudio.available ? Tokyo.blue : Tokyo.dim
                    leftPadding: 4
                    bottomPadding: 2
                }
                Rectangle {
                    width: parent.width; height: 1
                    color: PhoneAudio.available ? Tokyo.bgHighlight
                                                : Qt.rgba(0.18, 0.20, 0.30, 0.5)
                }

                Rectangle {
                    id: phoneRow
                    width: parent.width
                    height: root.rowHeight
                    radius: 6
                    // No hover fill when the row is dead: the fill is the
                    // "this does something" signal, and this does not.
                    color: phoneHover.hovered && PhoneAudio.available
                           ? Tokyo.bgHighlight : "transparent"

                    Row {
                        anchors {
                            left: parent.left; right: parent.right
                            leftMargin: 8; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        Text {
                            width: parent.width - 60
                            text: PhoneAudio.available
                                ? PhoneAudio.phone
                                : "No phone connected"
                            elide: Text.ElideRight
                            color: !PhoneAudio.available ? Tokyo.dim
                                  : PhoneAudio.on ? Tokyo.cyan : Tokyo.fg
                            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
                            verticalAlignment: Text.AlignVCenter
                        }
                        Toggle {
                            width: 34; height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            checked: PhoneAudio.on
                            interactive: PhoneAudio.available
                            opacity: PhoneAudio.available ? 1 : 0.4
                            onToggled: PhoneAudio.toggle()
                        }
                    }

                    MouseArea {
                        id: phoneHover
                        // Stops short of the switch's own hit area (8px margin
                        // + the 34px switch), so the row and the switch never
                        // both swallow one click.
                        anchors { left: parent.left; right: parent.right
                                  rightMargin: 42
                                  top: parent.top; bottom: parent.bottom }
                        hoverEnabled: true
                        onClicked: {
                            if (PhoneAudio.available)
                                PhoneAudio.toggle()
                        }
                    }

                    // ---------- the tooltip ----------
                    // A panel of its own rather than another line in the column:
                    // an inline explanation would make the whole panel jump
                    // taller every time the pointer crossed the row, which is
                    // worse than the problem it explains. This floats over the
                    // rows below instead, and is shown whenever the routing is
                    // OFF — the label alone cannot say why, and the app's
                    // status reason is exactly the hint you need.
                    Rectangle {
                        id: phoneTip
                        width: tipText.width + 20
                        height: tipText.height + 20
                        radius: Tokyo.pillRadius
                        color: Tokyo.bgDark
                        border.color: Tokyo.bgHighlight
                        border.width: 1
                        visible: opacity > 0.01
                        opacity: (!PhoneAudio.on && phoneHover.hovered)
                                 ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                        }
                        anchors { left: parent.left; leftMargin: 2
                                  top: parent.bottom; topMargin: 2 }
                        z: 10
                        Text {
                            id: tipText
                            anchors { left: parent.left; right: parent.right
                                      top: parent.top; margins: 10 }
                            text: PhoneAudio.summary
                            color: Tokyo.fg
                            wrapMode: Text.WordWrap
                            width: 236
                            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize - 1 }
                        }
                    }
                }

                // ---------- volume ----------
                // The phone volume is 0-100, not the 0-1 the Pipewire sliders
                // above use, so this row carries its own slider in the same
                // shape as VolumeSlider. It dims the way the switch row above
                // does when there is nothing to move: routing off, or the CLI
                // reporting an unknown volume (-1).
                Rectangle {
                    id: phoneVolRow
                    width: parent.width
                    height: root.rowHeight
                    radius: 6
                    color: "transparent"
                    opacity: (PhoneAudio.on && PhoneAudio.volume >= 0) ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Row {
                        anchors {
                            left: parent.left; right: parent.right
                            leftMargin: 8; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        Text {
                            width: parent.width - 162
                            text: "Volume"
                            elide: Text.ElideRight
                            color: (PhoneAudio.on && PhoneAudio.volume >= 0)
                                   ? Tokyo.cyan : Tokyo.dim
                            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 40
                            text: PhoneAudio.volume >= 0
                                  ? PhoneAudio.volume + "%" : "--"
                            color: PhoneAudio.volume >= 0 ? Tokyo.fg : Tokyo.dim
                            font { family: Tokyo.fontFamily; pixelSize: 12 }
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        VolumeSlider {
                            width: 110
                            enabled: PhoneAudio.on && PhoneAudio.volume >= 0
                            phoneLike: true
                        }
                    }
                }
            }

            Item { height: 8 }

            // ---------- input devices ----------
            Text {
                text: "INPUT DEVICES"
                font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                color: Tokyo.blue
                leftPadding: 4
                bottomPadding: 2
            }
            Rectangle {
                width: parent.width; height: 1
                color: Tokyo.bgHighlight
            }
            Repeater {
                model: root.inputDevices
                delegate: deviceRow
            }

            Item { height: 8 }

            // ---------- applications ----------
            Text {
                text: "APPLICATIONS"
                font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                color: Tokyo.blue
                leftPadding: 4
                bottomPadding: 2
            }
            Rectangle {
                width: parent.width; height: 1
                color: Tokyo.bgHighlight
            }
            Repeater {
                model: root.apps
                delegate: appRow
            }

            Item { height: 8 }
            Rectangle {
                width: parent.width; height: 1
                color: Tokyo.bgHighlight
            }

            // ---------- advanced ----------
            // The boost switch is folded away under this rather than sitting in
            // the panel: going past 100% distorts and clips, so it should be one
            // deliberate click instead of something in the way every time the
            // panel opens. The label stays lit when the panel is closed and
            // boosting is on — otherwise the setting would be invisible while
            // still in effect.
            Rectangle {
                id: advancedButton
                width: parent.width
                height: root.rowHeight
                radius: 6
                color: advancedHover.hovered ? Tokyo.bgHighlight : "transparent"

                Text {
                    anchors { left: parent.left; leftMargin: 8
                              verticalCenter: parent.verticalCenter }
                    text: "ADVANCED"
                    color: root.advanced || AudioStates.overboost ? Tokyo.blue : Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    // chevron down = closed, and there is more below it
                    text: root.advanced ? "\uf077" : "\uf078"
                    color: root.advanced ? Tokyo.blue : Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                }
                MouseArea {
                    id: advancedHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.advanced = !root.advanced
                }
            }

            Column {
                width: parent.width
                visible: root.advanced
                // A Column counts hidden children, so the height has to go to 0
                // by hand or the flyout keeps a gap where the switch used to be.
                height: visible ? implicitHeight : 0

                Rectangle {
                    id: boostRow
                    width: parent.width
                    height: root.rowHeight
                    radius: 6
                    color: boostHover.hovered ? Tokyo.bgHighlight : "transparent"

                    Row {
                        anchors {
                            left: parent.left; right: parent.right
                            leftMargin: 8; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        Text {
                            width: parent.width - 40
                            text: "Allow volume to go up to 150%"
                            elide: Text.ElideRight
                            color: AudioStates.overboost ? Tokyo.cyan : Tokyo.fg
                            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
                            verticalAlignment: Text.AlignVCenter
                        }
                        Toggle {
                            checked: AudioStates.overboost
                            onToggled: AudioStates.overboost = !AudioStates.overboost
                        }
                    }

                    MouseArea {
                        id: boostHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: AudioStates.overboost = !AudioStates.overboost
                    }
                }
            }
        }
    }

    // ---------------- device row (output + input) ----------------
    Component {
        id: deviceRow
        Rectangle {
            required property var modelData
            readonly property var node: modelData
            readonly property bool asInput: root.inputDevices.includes(modelData)
            readonly property bool isDefault: node && (asInput
                ? Pipewire.defaultAudioSource === node
                : Pipewire.defaultAudioSink === node)
            /// true while this input is looped into the output (see listenMods)
            readonly property bool listening: root.isListening(row.node)

            id: row
            width: parent.width
            height: root.rowHeight
            radius: 6
            // `|| sld.hovered` is not redundancy: the row's MouseArea stops at
            // the slider, and Qt only propagates hover to ancestors, never to
            // siblings — so hovering the slider would blank the row behind it.
            color: hover.hovered || (row.controllable && sld.hovered)
                   ? Tokyo.bgHighlight : "transparent"

            // Only the device you are actually listening to / talking into gets
            // a volume control. Every other row is just a way to *choose* that
            // device, and a slider on a device nothing is routed through is a
            // control with no effect. The widths collapse to 0 by hand rather
            // than relying on `visible: false`, which a Row still lays out.
            readonly property bool controllable: row.isDefault
                    && !!root.audioFor(row.node, row.asInput)

            Row {
                anchors {
                    left: parent.left; right: parent.right
                    leftMargin: 8; rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                Text {
                    // 26 = the 20px check + its 6px gap. The control column is
                    // percent 40 + mute 20 + slider 110 plus the three gaps
                    // between them and the check's — 214 — i.e. everything that
                    // is not the name. An input row adds the 20px listen glyph
                    // and its gap on the far right, so it reserves 26 more.
                    width: parent.width - (row.controllable ? 214 : 26)
                           - (row.asInput ? 26 : 0)
                    text: root.friendlyName(row.node)
                    elide: Text.ElideRight
                    color: row.isDefault ? Tokyo.blue : Tokyo.fg
                    font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
                    verticalAlignment: Text.AlignVCenter
                }
                VolumePercent {
                    width: row.controllable ? 40 : 0
                    audio: row.controllable ? root.audioFor(row.node, row.asInput) : null
                }
                MuteGlyph {
                    width: row.controllable ? 20 : 0
                    audio: root.audioFor(row.node, row.asInput)
                    isInput: row.asInput
                }
                VolumeSlider {
                    id: sld
                    width: row.controllable ? 110 : 0
                    audio: root.audioFor(row.node, row.asInput)
                }
                Text {
                    width: 20
                    text: "\uf00c" // check
                    color: row.isDefault ? Tokyo.green : "transparent"
                    font { family: Tokyo.fontFamily; pixelSize: 12 }
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                // ---------- listen to mic ----------
                // Input rows only; a zero-width no-op on output rows, so their
                // layout is untouched. Lit cyan while the loopback is up. The
                // MouseArea is on the glyph, and the row's own select MouseArea
                // stops short of it (see `hover` below) so the two never both
                // swallow one click.
                Item {
                    width: row.asInput ? 20 : 0
                    height: parent.height
                    visible: row.asInput
                    Text {
                        anchors.centerIn: parent
                        // \uF025 headphones — "hear this", distinct from the
                        // \uF130/\uF131 mic glyphs that mute the input itself.
                        text: "\uf025"
                        color: row.listening ? Tokyo.cyan : Tokyo.fg
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleListen(row.node)
                    }
                }
            }

            MouseArea {
                id: hover
                // Stops short of the volume control, or the row would eat every
                // drag and press on the one slider that is supposed to do
                // something. On a row with no control it still spans the width.
                // rightMargin, not `right: muteArea.left`: the glyph is a
                // grandchild through the Row, and QML refuses to anchor to
                // anything that is not a parent or a sibling. 206 = the Row's
                // own 8px right margin + mute 20 + gap 6 + slider 110 + gap 6
                // + percent 40 + gap 6, i.e. everything from the percentage's
                // left edge to the row's right edge. The check mark lives inside
                // that span and stays non-clickable, which is right: it is a
                // marker on a row already switched on.
                anchors {
                    left: parent.left; top: parent.top; bottom: parent.bottom
                    right: parent.right
                    // 8px Row margin + 20px listen glyph on an input row, so
                    // its click reaches the glyph and not this select handler.
                    rightMargin: row.controllable ? 206 : (row.asInput ? 28 : 0)
                }
                hoverEnabled: true
                onClicked: root.setDefault(row.node, row.asInput)
            }
        }
    }

    // ---------------- application row ----------------
    Component {
        id: appRow
        // A Column, not a plain Rectangle: the row carries its MOVE drawer
        // beneath it, and only the Column's implicitHeight grows when the
        // drawer is open. The other delegates stay Rectangles and the list
        // keeps its even row heights.
        Column {
            required property var modelData
            readonly property var node: modelData

            id: col
            width: parent.width

            Rectangle {
                id: row
                width: parent.width
                height: root.rowHeight
                radius: 6
                color: "transparent"

                Row {
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 8; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Text {
                        // 98: the route glyph (20) is what ate the old 118.
                        width: 98
                        text: root.friendlyName(col.node)
                        elide: Text.ElideRight
                        color: Tokyo.fg
                        font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
                        verticalAlignment: Text.AlignVCenter
                    }
                    VolumePercent {
                        width: 40
                        audio: col.node ? col.node.audio : null
                    }
                    MuteGlyph {
                        width: 20
                        audio: col.node ? col.node.audio : null
                    }

                    // 150% with AMPLIFY on, the usual 100% ceiling without it.
                    // 202 = the fixed siblings + their gaps, unchanged.
                    VolumeSlider {
                        width: parent.width - 202
                        audio: col.node ? col.node.audio : null
                    }

                    // The move-to-device switch: opens this app's MOVE drawer.
                    Item {
                        width: 20
                        height: parent.height
                        Text {
                            anchors.centerIn: parent
                            text: "\uf0ec"
                            color: root.routeFor === col.node ? Tokyo.cyan : Tokyo.fg
                            font { family: Tokyo.fontFamily; pixelSize: 11 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.routeFor = (root.routeFor === col.node) ? null : col.node
                        }
                    }
                }
            }

            // ---------- MOVE drawer ----------
            // The list of every sink an app's stream could be sent to, with a
            // check on the one it is playing through now. Polls run only while
            // this drawer is open (see routeFor). The folded height goes to 0
            // by hand for the same reason as the ADVANCED drawer: a hidden
            // Column still counts its children.
            Column {
                width: parent.width
                visible: root.routeFor === col.node
                height: visible ? implicitHeight : 0
                spacing: 2

                Text {
                    width: parent.width
                    leftPadding: 8
                    topPadding: 2
                    bottomPadding: 2
                    text: {
                        const si = root.sinkInputFor(col.node)
                        if (!si) return root.friendlyName(col.node) + " · not playing"
                        return "MOVE " + root.friendlyName(col.node) + " TO"
                    }
                    elide: Text.ElideRight
                    color: Tokyo.blue
                    font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                }

                Repeater {
                    model: root.routeTargets
                    delegate: Rectangle {
                        required property var modelData
                        readonly property var target: modelData

                        id: tgtRow
                        width: parent.width
                        height: 28
                        radius: 4
                        color: tgtHover.hovered ? Tokyo.bgHighlight : "transparent"
                        // dead when pactl cannot see the app's stream (e.g. it
                        // only exists inside PipeWire's graph so far)
                        opacity: root.sinkInputFor(col.node) ? 1 : 0.5

                        Row {
                            anchors {
                                left: parent.left; right: parent.right
                                leftMargin: 8; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 6

                            Text {
                                width: parent.width - 26
                                text: root.friendlyTarget(target)
                                elide: Text.ElideRight
                                color: root.routeDeviceFor(col.node) === target
                                       ? Tokyo.cyan : Tokyo.fg
                                font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize - 1 }
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: 20
                                text: "\uf00c" // check
                                color: root.routeDeviceFor(col.node) === target
                                       ? Tokyo.green : "transparent"
                                font { family: Tokyo.fontFamily; pixelSize: 12 }
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        MouseArea {
                            id: tgtHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !!root.sinkInputFor(col.node)
                            onClicked: root.moveApp(col.node, target)
                        }
                    }
                }
            }
        }
    }
}