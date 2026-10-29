// Island.qml — saneAspect-style dynamic island for the tokyonight bar.
//
// One near-black capsule at the top centre holds the whole bar: workspace dots,
// clock, now-playing, volume and the control-centre pill. Clicking a section
// grows a panel under the capsule.
//
// The panel is its own xdg_popup, not part of the bar's layer surface, for two
// reasons: the bar is 34px tall and cannot hold a panel, and a layer surface
// grown to panel height would swallow clicks across the top of the screen even
// where it is transparent. A popup only takes input over its own rectangle and
// the compositor dismisses it on an outside click for free.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Item {
    id: root

    required property var screen
    property var tooltipHost: null
    /// True on the monitor the launcher window is on, while it is mapped.
    property bool launcherOpen: false
    /// True on the monitor the theme picker is on, while it is mapped.
    property bool pickerOpen: false
    /// True on the monitor the clipboard picker is open on. The picker is an
    /// overlay window, so an open flyout would otherwise sit on top of its
    /// field; opening it closes the flyout.
    property bool clipboardOpen: false
    onClipboardOpenChanged: if (root.clipboardOpen) root.close()

    /// Module whose flyout is open, or null. The module owns the panel
    /// component and the panel owns its width — see Module.qml and Panel.qml.
    property var panelModule: null

    /// Size of the panel that is open (or would open). The capsule is the
    /// panel's header, so it takes this width while a panel is showing.
    readonly property real panelWidth: panelLoader.item ? panelLoader.item.implicitWidth : 0
    readonly property real panelHeight: panelLoader.item ? panelLoader.item.implicitHeight : 0
    /// The header can never shrink below its own pills, so a future panel
    /// narrower than the row still leaves capsule and card the same width.
    readonly property real openWidth: Math.max(root.panelWidth,
                                               row.implicitWidth + Tokyo.islandPadH * 2)

    /// The surface cannot resize per frame (a mid-animation resize renders a
    /// sliver), so while two panels are morphing it holds the larger of them.
    readonly property real surfaceWidth: Math.max(root.openWidth,
            outgoingLoader.item ? outgoingLoader.item.implicitWidth : 0)
    readonly property real surfaceHeight: Math.max(root.panelHeight,
            outgoingLoader.item ? outgoingLoader.item.implicitHeight : 0)

    width: capsule.width
    height: Tokyo.islandHeight

    readonly property var now: clockPill.now

    /// Width the capsule is drawing right now.
    readonly property real capsuleWidth: capsule.width

    /// True while the drawer is sliding back up. The surface stays mapped
    /// until that slide finishes, so closing mirrors opening.
    property bool closing: false
    /// Flyout being faded out while the card morphs to the next one, or null.
    /// Non-null == a morph is in flight.
    property var outgoingModule: null
    /// 0 at the start of a morph, 1 when it lands. Drives the crossfade.
    property real morphProgress: 1
    onMorphProgressChanged: if (morphProgress === 1) root.outgoingModule = null

    function open(module) {
        closeTimer.stop()
        root.closing = false
        root.panelModule = module
        popup.visible = true
        Qt.callLater(() => card.forceActiveFocus())
    }

    function toggle(module) {
        if (!popup.visible) root.open(module)
        else if (root.panelModule === module) root.close()
        else root.switchTo(module)
    }

    // Same pill row, new panel: the card morphs its width/height and the two
    // contents crossfade. Nothing retracts and the surface never unmaps.
    function switchTo(module) {
        closeTimer.stop()
        root.closing = false
        root.outgoingModule = root.panelModule
        root.morphProgress = 0
        root.panelModule = module
        morphAnim.restart()
    }

    function close() {
        if (!popup.visible || root.closing) return
        root.closing = true
        closeTimer.start()
    }

    // Unmaps after the reverse slide. The compositor's own outside-click
    // dismissal cannot be delayed, so that close stays instant.
    Timer {
        id: closeTimer
        interval: Tokyo.flyoutDuration
        onTriggered: popup.visible = false
    }

    // Morph driver. Finishing at 1 is also what drops the outgoing panel and
    // lets the surface shrink to the panel that is now on screen.
    NumberAnimation {
        id: morphAnim
        target: root
        property: "morphProgress"
        to: 1
        duration: Tokyo.flyoutDuration
        easing.type: Easing.OutCubic
    }

    RectangularShadow {
        anchors.fill: capsule
        radius: capsule.radius
        blur: Tokyo.shadowBlur
        offset: Qt.vector2d(0, Tokyo.shadowOffsetY)
        color: Tokyo.shadowColor
    }

    Rectangle {
        id: capsule
        anchors.verticalCenter: parent.verticalCenter
        // The launcher and picker cards are exactly as wide as this; widening
        // the capsule while one is open lets the card's square top join the
        // capsule's square bottom edge instead of poking out under a narrow pill.
        width: root.pickerOpen ? Tokyo.pickerWidth
                                 : root.launcherOpen ? Tokyo.launcherWidth
                                 : popup.visible ? root.openWidth
                                 : row.implicitWidth + Tokyo.islandPadH * 2
        Behavior on width {
            // Animates into a panel morph too, keeping the header exactly as
            // wide as the card on every frame (same duration and easing).
            enabled: !popup.visible || root.outgoingModule !== null
            NumberAnimation {
                duration: root.outgoingModule !== null
                          ? Tokyo.flyoutDuration
                          : (root.launcherOpen || root.pickerOpen)
                            ? Tokyo.expandDuration : Tokyo.collapseDuration
                easing.type: Easing.OutCubic
            }
        }
        height: Tokyo.islandHeight
        radius: height / 2
        // While a panel is open the capsule is the panel's header, so its
        // bottom corners square off into the card (which is at least as wide).
        // The launcher's window carries the same header shape.
        bottomLeftRadius: popup.visible || root.launcherOpen || root.pickerOpen ? 0 : height / 2
        bottomRightRadius: popup.visible || root.launcherOpen || root.pickerOpen ? 0 : height / 2
        Behavior on bottomLeftRadius {
            NumberAnimation { duration: Tokyo.collapseDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: Tokyo.collapseDuration; easing.type: Easing.OutCubic }
        }
        color: Tokyo.islandFill

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Tokyo.islandGap

            Workspaces {
                screen: root.screen
                Layout.alignment: Qt.AlignVCenter
            }

            Clock {
                id: clockPill
                flat: true
                hoverStyle: true
                hPad: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(clockPill)
            }

            // Only visible while a player has a track; a paused player keeps
            // the pill, a closed one takes it away.
            Media {
                id: mediaPill
                flat: true
                hoverStyle: true
                hPad: 0
                tooltipHost: root.tooltipHost
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(mediaPill)
            }

            Audio {
                id: audioPill
                flat: true
                hoverStyle: true
                hPad: 0
                tooltipHost: root.tooltipHost
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(audioPill)
            }

            // Everything that is not clock, now-playing or volume shares one
            // flyout: separate pills would push the capsule past the edge.
            Quick {
                id: quickPill
                flat: true
                hoverStyle: true
                hPad: 0
                tooltipHost: root.tooltipHost
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(quickPill)
            }

            // Notifications live in swaync, so the bell is a toggle for its
            // control centre rather than a panel of our own — the count is the
            // only state quickshell keeps.
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight

                Module {
                    id: bell
                    text: "󰂚"
                    flat: true
                    hoverStyle: true
                    hPad: 0
                    tooltip: "Notifications"
                    tooltipHost: root.tooltipHost
                    onClicked: Quickshell.execDetached(["swaync-client", "-t"])
                }

                Rectangle {
                    visible: bellCount.value > 0
                    anchors { right: parent.right; top: parent.top
                              topMargin: -3; rightMargin: -5 }
                    width: Math.max(12, badgeText.implicitWidth + 6)
                    height: 12
                    radius: height / 2
                    color: Tokyo.blue
                    // Pops in when the first notification lands.
                    scale: visible ? 1 : 0.4
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                    }

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: bellCount.value > 99 ? "99+" : String(bellCount.value)
                        color: Tokyo.islandFill
                        font { family: Tokyo.fontFamily; pixelSize: 8; bold: true }
                    }
                }

                Poll {
                    id: bellCount
                    property int value: 0
                    // swaync-client prints the count without a newline, and a
                    // line parser only emits complete lines — the echo flushes it.
                    // Only ask while swaync runs: swaync-client's D-Bus lookup
                    // activates the daemon, so an unguarded poll would start it
                    // two seconds after login and defeat the D-Bus activation.
                    command: ["sh", "-c", "pgrep -x swaync >/dev/null && swaync-client -c -sw; echo"]
                    interval: 2000
                    onResult: line => {
                        const n = parseInt(String(line).trim())
                        bellCount.value = isNaN(n) ? 0 : n
                    }
                }
            }
        }
    }

    PopupWindow {
        id: popup
        color: "transparent"
        visible: false
        implicitWidth: root.surfaceWidth
        implicitHeight: Math.max(1, root.surfaceHeight)

        // An xdg_popup dismisses itself on an outside click, and that write
        // drops the binding on `visible` — so the state has to follow the
        // window, not the other way round. A morph that is still running lands
        // here too, so its outgoing panel is dropped with the rest.
        onVisibleChanged: if (!visible) {
            root.panelModule = null
            root.outgoingModule = null
            root.closing = false
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: root.close()
        }

        Component.onCompleted: {
            popup.anchor.item = capsule
            popup.anchor.edges = Edges.Bottom
            popup.anchor.gravity = Edges.Bottom
            popup.anchor.adjustment = PopupAdjustment.All
        }

        Rectangle {
            id: card
            focus: true
            Keys.onEscapePressed: root.close()

            width: root.openWidth
            // Morph only: opening and closing keep their slide and their
            // instant size, since the surface is not resized per frame.
            Behavior on width {
                enabled: root.outgoingModule !== null
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutCubic }
            }
            // Never 0: closing nulls panelModule, the loader drops its item and
            // this binding collapses in the same commit — a 0-height xdg_popup
            // buffer is a Wayland protocol error and kills the process.
            height: Math.max(1, root.panelHeight)
            Behavior on height {
                enabled: root.outgoingModule !== null
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutCubic }
            }
            // The surface holds the larger of the two panels while morphing, so
            // the card is centred in it rather than left-aligned (the popup is
            // centred under the capsule).
            x: (root.surfaceWidth - width) / 2
            // Drawer: the popup surface is already this tall, so the whole card
            // slides down from behind the capsule, and back up on close.
            // Animating the surface's own height instead resizes it mid-map and
            // renders a sliver. Multiplying by `height` keeps the offset right
            // if the panel's height lands a frame late.
            property real reveal: popup.visible && !root.closing ? 1 : 0
            Behavior on reveal {
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutCubic }
            }
            y: -height * (1 - reveal)
            radius: Tokyo.islandPanelRadius
            // Square at the top: the capsule is the panel's header, is exactly
            // this wide and meets this edge, so the two read as one shape.
            topLeftRadius: 0
            topRightRadius: 0
            color: Tokyo.islandFill
            clip: true

            // Fades out under the incoming panel while the card morphs.
            Loader {
                id: outgoingLoader
                width: card.width
                sourceComponent: root.outgoingModule ? root.outgoingModule.panel : null
                opacity: 1 - root.morphProgress
            }

            Loader {
                id: panelLoader
                width: card.width
                sourceComponent: root.panelModule ? root.panelModule.panel : null
                // Rides the slide; during a morph the slide is already at 1 and
                // the crossfade takes over.
                opacity: card.reveal * (root.outgoingModule !== null ? root.morphProgress : 1)
            }
        }
    }
}
