// Settings.qml — the internet and the power tools in ONE pill (they were two).
//
// Three glyphs, no text: the ethernet cable in blue while enp14s0 has carrier,
// the wifi glyph while a link is associated, and the power glyph, which is the
// same one the shutdown button in the flyout wears. The wifi glyph carries the
// link's strength — one to four arcs — so the bar says how good the connection
// is without a number to read. Each net icon is there only while its link is
// up, so the pill carries just the one that is actually moving data. The power
// glyph is always there — it is the way into the menu, and a pill that changes
// width as you unplug things is a moving target.
//
// Everything the pill used to say in a tooltip is now one click away in
// SettingsFlyout, so no tooltip: the network block, the SSID reveal, the
// bluetooth devices and the power actions all live in there.
import QtQuick
import Quickshell

Module {
    id: root

    property var networkMonitor: null
    /// SettingsFlyout to toggle (created in Bar.qml)
    property var flyoutHost: null

    // ---------- net state (was Net.qml) ----------
    /// raw script output per link
    // showSsid defaults false: hidden until the flyout's button says otherwise.
    property var wifi: ({ label: "wifi", showSsid: false, tooltip: "" })
    property var eth: ({ label: "ethernet", showSsid: false, tooltip: "" })

    readonly property var adapters: root.networkMonitor ? root.networkMonitor.adapters : []

    function findAdapter(name) {
        if (!Array.isArray(root.adapters)) return null
        for (let i = 0; i < root.adapters.length; i++) {
            if (root.adapters[i] && root.adapters[i].name === name)
                return root.adapters[i]
        }
        return null
    }

    readonly property bool ethUp: {
        const a = root.findAdapter("enp14s0")
        return a !== null && a.state === "up"
    }
    readonly property bool wifiUp: {
        if (!Array.isArray(root.adapters)) return false
        return root.adapters.some(a => a && a.activeWifi === true)
    }
    /// wired wins when both are up — it is the link everything else rides on
    readonly property bool primaryEthernet: root.ethUp

    // ---------- signal quality ----------
    /// One tiering of the signal, so the pill's glyph, the flyout's rows and
    /// the tile cannot disagree: 80/60/35 is also what the rows have always
    /// used, and a link that reads 70% is one story everywhere it appears.
    function bars(signal) {
        return signal >= 80 ? 4 : signal >= 60 ? 3 : signal >= 35 ? 2 : 1
    }
    /// The MDI wifi-strength glyphs — one to four arcs, weakest first — as
    /// found in the Nerd Font (U+F091F, U+F0922, U+F0925, U+F0928). Kept as
    /// escapes and not literal characters because a raw PUA glyph is
    /// invisible in a diff, which is how the wrong icon ships unnoticed.
    readonly property var wifiGlyphs: ["\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]
    function signalGlyph(tier) {
        return tier >= 1 && tier <= 4 ? root.wifiGlyphs[tier - 1] : "\uf1eb"
    }
    /// The active wifi adapter's signal (0-100) from network-monitor.sh, or
    /// -1 while nothing has reported one — radio off, or the first sample is
    /// still a second away. Never 0: 0 would mean "one bar of a real
    /// reading", which is not the same statement as "no reading".
    readonly property int wifiSignal: {
        const a = root.findWifiAdapter(root.adapters)
        return a && typeof a.signal === "number" ? a.signal : -1
    }
    /// What the wifi glyph wears wherever it appears: the strength tier while
    /// there is a reading, the plain wifi glyph until there is one.
    readonly property string wifiGlyph: root.wifiSignal < 0
        ? "\uf1eb" : root.signalGlyph(root.bars(root.wifiSignal))

    // ---------- connection stats (was Net.qml, read by the flyout) ----------
    /// The WI-FI section's reveal/hide button, and the only thing that decides
    /// whether the network name is readable. Read from wifi.sh's own
    /// `showSsid` rather than guessed from the label: a network actually named
    /// "wifi" must not read as permanently hidden.
    readonly property bool ssidShown: root.wifi.showSsid === true

    Poll {
        id: wifiPoll
        command: [Tokyo.scriptDir + "/wifi.sh"]
        interval: 60000
        onResult: output => root.wifi = root.parseJson(output, root.wifi)
    }

    Poll {
        id: ethPoll
        command: [Tokyo.scriptDir + "/ethernet.sh"]
        interval: 60000
        onResult: output => root.eth = root.parseJson(output, root.eth)
    }

    // Flip the button on the spot, then let the poll correct us. wifi.sh takes
    // a moment (it shells out for the SSID), so waiting for it before showing
    // anything left the tab looking broken for the best part of a second.
    Timer {
        id: postToggle
        interval: 400
        onTriggered: wifiPoll.refresh()
    }

    function toggleSsid() {
        Quickshell.execDetached([Tokyo.scriptDir + "/wifi-toggle.sh"])
        // New object, not a field write: `wifi` is a `var` and bindings only
        // re-run when the reference itself changes.
        root.wifi = Object.assign({}, root.wifi,
                                 { showSsid: !root.ssidShown })
        postToggle.start()
    }

    function parseJson(out, fallback) {
        try {
            const o = JSON.parse(out)
            // both scripts prefix their label with the nerd-font glyph
            const label = String(o.text ?? "").replace(/^\S+\s+/, "").trim()
            return {
                label: label === "" ? fallback.label : label,
                // wifi.sh reports the reveal state; ethernet.sh has no such
                // field, so it keeps the last one it was given.
                showSsid: o.showSsid === undefined
                    ? fallback.showSsid
                    : o.showSsid === true,
                tooltip: o.tooltip ?? fallback.tooltip,
            }
        } catch (e) {
            return fallback
        }
    }

    function valueOrDash(value) {
        return (value === undefined || value === null || value === "") ? "-" : String(value)
    }

    function hasValue(value) {
        return value !== undefined && value !== null && value !== "" && value !== "-"
    }

    /// null-safe: the wifi adapter is looked up by a flag and may be absent
    function metricLines(adapter) {
        if (adapter === null || adapter === undefined)
            return []

        return [
            "Download: " + root.valueOrDash(adapter.rxRate),
            "Upload: " + root.valueOrDash(adapter.txRate),
            "External ping (1.1.1.1): " + root.valueOrDash(adapter.externalPing),
        ]
    }

    function findWifiAdapter(records) {
        if (!Array.isArray(records))
            return null

        for (let i = 0; i < records.length; i++) {
            if (records[i].activeWifi === true)
                return records[i]
        }
        return null
    }

    function adapterBlock(adapter) {
        const lines = [
            "Interface: " + root.valueOrDash(adapter.name),
            "IP: " + root.valueOrDash(adapter.ip),
            "Netmask: " + root.valueOrDash(adapter.netmask),
        ]
        if (root.hasValue(adapter.dns))
            lines.push("DNS: " + root.valueOrDash(adapter.dns))
        if (root.hasValue(adapter.mac))
            lines.push("MAC: " + root.valueOrDash(adapter.mac))
        return lines.concat(root.metricLines(adapter))
    }

    function withMetrics(base, blocks) {
        if (blocks.length === 0)
            return base

        const prefix = base === "" ? "" : String(base).replace(/\n+$/, "") + "\n"
        return prefix + blocks.join("\n\n")
    }

    /// ssid/ip/netmask + dns/mac + the active wifi adapter's live rates.
    /// The three rates are ONE block, so they are joined here: `withMetrics`
    /// separates blocks with a blank line (that is what keeps the per-adapter
    /// blocks apart), and handing it the three lines separately gave each of
    /// them its own blank line.
    ///
    /// The SSID line is masked unless the button has revealed it. This is the
    /// only place the name is ever shown now that the pill is icons only, so it
    /// is also the only place the button can have an effect.
    readonly property string wifiTooltip: root.withMetrics(
        root.ssidForDisplay(root.wifi.tooltip),
        [root.metricLines(root.findWifiAdapter(root.adapters)).join("\n")])

    /// The SSID line as the flyout is allowed to show it: the name once
    /// revealed, dots until then. The line itself is always kept, so the block
    /// does not change shape as the button flips.
    function ssidForDisplay(base) {
        if (root.ssidShown) return String(base)
        const text = String(base)
        if (!text.includes("SSID:")) return text
        return text.replace(/^(SSID: ).*$/m, "$1•••••••")
    }

    /// enp14s0's live rates first, then every other non-loopback adapter as
    /// its own block (the wifi record is the wifi section's business)
    readonly property string ethernetTooltip: {
        if (!Array.isArray(root.adapters))
            return root.eth.tooltip

        let primary = null
        const others = []
        for (let i = 0; i < root.adapters.length; i++) {
            const adapter = root.adapters[i]
            if (adapter.activeWifi === true)
                continue
            if (adapter.name === "enp14s0" && primary === null)
                primary = root.metricLines(adapter)
            else
                others.push(root.adapterBlock(adapter).join("\n"))
        }

        const blocks = []
        if (primary !== null)
            blocks.push(primary.join("\n"))
        for (let i = 0; i < others.length; i++)
            blocks.push(others[i])

        return root.withMetrics(root.eth.tooltip, blocks)
    }

    // ---------- bluetooth + wifi lists ----------
    readonly property string wifiListCmd: Tokyo.scriptDir + "/wifi-list.sh"
    readonly property string btStateCmd: Tokyo.scriptDir + "/bt-state.sh"

    /// bluez's `Icon:` class -> a Nerd Font glyph, so a row says what the
    /// device is before you read its name. An unknown class falls back to the
    /// plain bluetooth glyph.
    function btGlyph(icon) {
        switch (icon) {
        case "input-gaming":    return "\uf11b"
        case "input-keyboard":  return "\uf11c"
        case "input-mouse":     return "\uf245"
        case "audio-card":
        case "audio-headset":
        case "audio-headphones": return "\uf025"
        case "phone":           return "\uf10b"
        case "computer":        return "\uf109"
        case "printer":         return "\uf02f"
        case "camera-photo":
        case "camera-video":    return "\uf030"
        case "video-display":   return "\uf108"
        default:                return "\uf293"
        }
    }

    property var wl: ({ radio: true, active: "", networks: [] })
    property var bt: ({ powered: true, devices: [] })
    /// discovery results, kept apart from the paired list on purpose: scanning
    /// finds neighbours, and those must not be listed as if they were yours
    property var found: []
    /// true while bt-scan.sh is out listening — the list it fills arrives when
    /// it returns, so without this the button looks broken
    property bool scanning: false
    /// the MAC of the device row currently waiting on bluez, or "" for none.
    /// A MAC and not a bool because pairing is per device: the row you clicked
    /// is the one spinning, not the whole bluetooth section.
    property string btBusy: ""
    /// true while btBusy's click wants the device CONNECTED (vs disconnected),
    /// so the row settles on the state the click asked for, not a guess.
    property bool btBusyTarget: false
    property string notice: ""
    /// true while `notice` is a failure the user must see as one (the flyout
    /// colors error notices Tokyo.red, everything else Tokyo.yellow)
    property bool noticeError: false

    /// Paired devices and the scan results are one list between them; a paired
    /// device is just one that is already known. Rebuilt whenever either
    /// changes. A device with no name is dropped: it is a bare MAC, and a row
    /// saying so is one you cannot do anything with.
    readonly property var btList: {
        const out = []
        const seen = {}
        for (let i = 0; i < root.bt.devices.length; i++) {
            const d = root.bt.devices[i]
            if (!d.name) continue
            seen[d.mac] = true
            out.push({ mac: d.mac, name: d.name, paired: true,
                       connected: d.connected === true, icon: d.icon || "" })
        }
        for (let i = 0; i < root.found.length; i++) {
            const d = root.found[i]
            if (seen[d.mac] || !d.name) continue
            out.push({ mac: d.mac, name: d.name, paired: false,
                       connected: false, icon: d.icon || "" })
        }
        return out
    }

    Poll {
        id: wifiListPoll
        command: [root.wifiListCmd]
        interval: 30000
        onResult: out => root.wl = root.parseWifi(out)
    }

    Poll {
        id: btPoll
        command: [root.btStateCmd]
        interval: 20000
        onResult: out => root.bt = root.parseBt(out)
    }

    Poll {
        id: btScanPoll
        command: [Tokyo.scriptDir + "/bt-scan.sh", "10"]
        // Off until asked for: an always-on scan drains the phone's battery and
        // makes every device in the room show up in the list uninvited.
        active: false
        onResult: out => {
            root.scanning = false
            root.notice = ""
            try {
                root.found = JSON.parse(out).devices || []
            } catch (e) {
                root.found = []
            }
        }
    }

    function parseWifi(out) {
        try {
            const o = JSON.parse(out)
            return {
                radio: o.radio === true,
                active: o.active || "",
                networks: Array.isArray(o.networks) ? o.networks : [],
            }
        } catch (e) {
            return root.wl
        }
    }

    function parseBt(out) {
        try {
            const o = JSON.parse(out)
            const devices = Array.isArray(o.devices) ? o.devices : []
            // Settle a busy row on the truth, not a guessed timeout: bt-dev.sh
            // can hold ~40s on a pair, so clear the spinner only once the
            // device's connected state matches what the click wanted, or once
            // it is gone from both lists. A brand-new device is not in the
            // paired list until the pair lands — it is only in `found` — so
            // that list has to count too or the spinner dies at the first poll.
            if (root.btBusy !== "") {
                let dev = null
                for (let i = 0; i < devices.length; i++)
                    if (devices[i].mac === root.btBusy) { dev = devices[i]; break }
                if (dev === null)
                    for (let i = 0; i < root.found.length; i++)
                        if (root.found[i].mac === root.btBusy) { dev = root.found[i]; break }
                if (dev === null
                        || (dev.connected === true) === root.btBusyTarget) {
                    root.btBusy = ""
                    root.notice = ""
                }
            }
            return {
                powered: o.powered === true,
                devices: devices,
            }
        } catch (e) {
            return root.bt
        }
    }

    /// Called by the flyout when it opens: the 30s and 20s polls are too slow
    /// to trust on open, and after any action this is what re-reads the truth.
    function refreshAll() {
        wifiPoll.refresh()
        ethPoll.refresh()
        wifiListPoll.refresh()
        btPoll.refresh()
        hdrPoll.refresh()
    }

    // ---------- live speedtest ----------
    /// The peak the line can currently reach, {"down":…,"up":…} in Mbit/s.
    /// `testing` is true only while a run is in flight; it is never true of
    /// the idle state. The last result stays on screen after a run, so the
    /// row never blanks when a refetch fails or a test has not run yet.
    property var speed: ({ down: 0, up: 0, testing: false })

    // Started by hand only: the test spends ~20s of this machine's bandwidth,
    // so a background rhythm is a hidden cost on every boot and every 10
    // minutes after. Poll starts once at load and again on the interval, so a
    // Poll with its command armed would measure itself; instead the command
    // stays empty until `startSpeedtest()` arms it for the flyout's button.
    // The transient-parse helper is the same try/catch the old cadence used.
    Poll {
        id: speedPoll
        command: []
        active: false
        onResult: out => {
            try {
                const o = JSON.parse(out)
                root.speed = {
                    down: Number(o.down) > 0 ? Number(o.down) : 0,
                    up: Number(o.up) > 0 ? Number(o.up) : 0,
                    testing: false,
                }
            } catch (e) {
                // Not our line (or a partial read): drop the spinner, keep
                // the last good numbers.
                root.speed = Object.assign({}, root.speed, { testing: false })
            }
        }
    }

    /// The flyout's START SPEEDTEST button. One run, now; the result lands in
    /// `speed` when it finishes. The command is armed here because armed at
    /// load the Poll would auto-run once for free — the very thing "only when
    /// I press the button" is meant to stop.
    function startSpeedtest() {
        if (root.speed.testing) return
        root.speed = Object.assign({}, root.speed, { testing: true })
        speedPoll.command = [Tokyo.scriptDir + "/speedtest.sh"]
        speedPoll.refresh()
    }

    // ---------- wifi action results ----------
    // WiFi actions are polls, not execDetached, because the user must SEE the
    // result: nmcli answers in seconds and "Joining…" for 4 seconds is all the
    // old detached run could show. Same arm-on-demand pattern as speedPoll.
    Poll {
        id: wifiActPoll
        command: []
        active: false
        onResult: out => root.settleWifiAct(out)
    }

    // ---------- HDR (the M28U on DP-1) ----------
    /// Runtime-only, and read back rather than assumed: hdr.sh's `on`/`off`
    /// each append a Hyprland monitor rule with no way to remove one, so the
    /// pill mirrors the monitor's own `colorManagementPreset` instead of
    /// holding a second copy that can drift.
    property bool hdr: false

    Poll {
        id: hdrPoll
        command: [Tokyo.scriptDir + "/hdr.sh", "status"]
        interval: 30000
        onResult: output => { root.hdr = output.trim() === "on" }
    }

    // ---------- actions ----------
    // The detached actions (bt pair/forget) can block for seconds waiting on a
    // phone, and a Poll would hold its process open that whole time. The wifi
    // join/leave/forget results are read by wifiActPoll instead (above), because
    // nmcli answers in seconds and the flyout must show the verdict.
    function run(script, args) {
        Quickshell.execDetached([script].concat(args || []))
    }

    function setWifiRadio(on) {
        root.run(Tokyo.scriptDir + "/wifi-radio.sh", [on ? "on" : "off"])
        // Optimistic, like the SSID button: nmcli returns before the radio has
        // actually dropped, so waiting for the poll leaves the switch lagging
        // behind the pointer.
        root.wl = Object.assign({}, root.wl, { radio: on })
        settle.start()
    }

    function setBtRadio(on) {
        root.run(Tokyo.scriptDir + "/bt-radio.sh", [on ? "on" : "off"])
        root.bt = Object.assign({}, root.bt, { powered: on })
        settle.start()
    }

    function setHdr(on) {
        root.run(Tokyo.scriptDir + "/hdr.sh", [on ? "on" : "off"])
        // Optimistic, like the radios: the monitor takes a beat to actually
        // change mode, so waiting for the poll would leave the switch lagging
        // behind the pointer.
        root.hdr = on
        settle.start()
    }

    /// Bring the wired link down or back up. There is no optimistic update
    /// here, unlike the two radios: `ethUp` is read from the interface's
    /// carrier, and carrier does not answer until the interface has actually
    /// gone quiet — an optimistic write would light the switch for a link that
    /// is still up, or blank it for one that is still carrying. The 900ms
    /// settle is enough for nmcli to finish the transition.
    function setEthEnabled(on) {
        root.run(Tokyo.scriptDir + "/eth-radio.sh", [on ? "on" : "off"])
        settle.start()
    }

    /// The verdict of a wifi action, read from wifi-connect.sh's one JSON
    /// line. `ok:true` clears the notice and re-reads the world; `ok:false`
    /// shows the short reason in red for the same 4s a success would have
    /// shown "Joining…" — a failed join must read as a failure, not silence.
    function settleWifiAct(out) {
        try {
            const o = JSON.parse(out)
            if (o.ok === true) {
                root.notice = ""
                root.noticeError = false
                root.refreshAll()
            } else {
                root.notice = String(o.err || "Failed").slice(0, 120)
                root.noticeError = true
                root.refreshAll()
                root.confirm.start()
            }
        } catch (e) {
            // Not our line (or a partial read): drop the notice, re-read.
            root.notice = ""
            root.noticeError = false
            root.refreshAll()
        }
    }

    function joinWifi(ssid, password) {
        // A stale confirm timer from a previous failure would blank the
        // "Joining…" notice mid-flight, and join can hold 20s.
        root.confirm.stop()
        root.notice = "Joining " + ssid + "…"
        root.noticeError = false
        wifiActPoll.command = [Tokyo.scriptDir + "/wifi-connect.sh",
                               "join", ssid].concat(password ? [password] : [])
        wifiActPoll.refresh()
        wifiGuard.start()
    }

    function leaveWifi(ssid) {
        root.confirm.stop()
        root.notice = "Leaving…"
        root.noticeError = false
        wifiActPoll.command = [Tokyo.scriptDir + "/wifi-connect.sh",
                               "leave", ssid]
        wifiActPoll.refresh()
        wifiGuard.start()
    }

    function forgetWifi(ssid) {
        // Same wait-free arm as the other two: nmcli delete returns in a
        // moment, and the result poll's refreshAll drops the row anyway
        // because the network is no longer `known`.
        root.confirm.stop()
        root.notice = "Forgetting…"
        root.noticeError = false
        wifiActPoll.command = [Tokyo.scriptDir + "/wifi-connect.sh",
                               "forget", ssid]
        wifiActPoll.refresh()
        wifiGuard.start()
    }

    function scanBluetooth() {
        root.scanning = true
        root.notice = "Scanning…"
        // A new, ordinary (non-error) notice: drop any leftover failure tint.
        root.noticeError = false
        btScanPoll.refresh()
    }

    function toggleDevice(mac, paired, connected) {
        // A busy row must not start a second command: bt-dev.sh can hold the
        // device for ~40s, and a second click would stack a second script on
        // the same bluez object. KDE blocks double-actions the same way.
        if (root.btBusy !== "") return
        root.notice = ""
        // Busy from before the script is even spawned: bt-dev.sh pair blocks for
        // up to 25s waiting on the phone, and a row that only spins once the
        // script returns looks like nothing happened for those 25 seconds.
        root.btBusy = mac
        root.btBusyTarget = (!paired || !connected)
        if (!paired || !connected)
            root.run(Tokyo.scriptDir + "/bt-dev.sh", ["connect", mac])
        else
            root.run(Tokyo.scriptDir + "/bt-dev.sh", ["disconnect", mac])
        // No fixed confirm: bt-dev.sh can hold ~40s, so the row is held by the
        // two watches below until the state actually changes (btWatch polls) or
        // the pair fails outright (btGuard, the 45s backstop).
        btWatch.start()
        btGuard.start()
    }

    function forgetDevice(mac) {
        // Say something, unlike toggleDevice's silent clear: `run` is
        // execDetached and bt-dev.sh pipes both of its commands to /dev/null,
        // so a forget that fails returns nothing to notice and the row just
        // sits there for 4s looking broken. This matches what joinWifi,
        // leaveWifi and scanBluetooth already do.
        root.notice = "Forgetting…"
        // A new, ordinary (non-error) notice: drop any leftover failure tint.
        root.noticeError = false
        // No busy spinner here, unlike toggleDevice: a forget is immediate, and
        // the row is about to leave the list anyway — spinning would only claim
        // the row is doing something when what it is doing is disappearing.
        root.run(Tokyo.scriptDir + "/bt-dev.sh", ["forget", mac])
        // bt-dev.sh returns as soon as bluez is told, and the removal lands a
        // moment later, so the list on screen is still stale. The same
        // confirming poll a toggle uses is what finally drops the row.
        confirm.start()
    }

    // One timer for every deferred re-poll: whatever was just clicked needs a
    // beat to actually take effect before the poll will show it.
    Timer {
        id: settle
        interval: 900
        onTriggered: root.refreshAll()
    }
    Timer {
        id: confirm
        interval: 4000
        onTriggered: { root.refreshAll(); root.notice = "" }
    }

    // btBusy is owned by parseBt, which clears it when the device settles; a
    // poll this fast just gets the settle answer sooner for a quick op.
    Timer {
        id: btWatch
        interval: 1500
        repeat: true
        running: root.btBusy !== ""
        onTriggered: btPoll.refresh()
    }
    // Backstop for a pair that simply fails: the state never changes, so the
    // settle-on-result above never fires and the row would spin forever. Say
    // which device failed rather than going silent — a spinner that just stops
    // reads as "still working", not "gave up".
    function btBusyName() {
        for (let i = 0; i < root.btList.length; i++)
            if (root.btList[i].mac === root.btBusy) return root.btList[i].name
        for (let i = 0; i < root.found.length; i++)
            if (root.found[i].mac === root.btBusy) return root.found[i].name
        return root.btBusy
    }
    Timer {
        id: btGuard
        interval: 45000
        onTriggered: if (root.btBusy !== "") {
            root.notice = "Couldn't connect to " + root.btBusyName()
            root.noticeError = true
            root.btBusy = ""
            root.confirm.start()
        }
    }

    // If the wifi action process dies without printing its verdict, the
    // armed poll never fires onResult and "Joining…" would stick forever —
    // the old confirm-based flow capped every notice at 4s. Clear an
    // in-progress (non-error) notice after 30s and re-read the world.
    Timer {
        id: wifiGuard
        interval: 30000
        onTriggered: if (root.notice !== "" && !root.noticeError) {
            root.notice = ""
            root.refreshAll()
        }
    }

    /// The pill is the three glyphs and nothing else: no link name, no SSID, no
    /// "off". The power glyph is last, so it sits against the screen edge and
    /// the net icons read as its traffic rather than the other way round.
    fragments: [
        {
            text: "\uef44",
            color: Tokyo.blue,
            visible: root.ethUp,
        },
        {
            text: root.wifiGlyph,
            color: Tokyo.cyan,
            visible: root.wifiUp,
        },
        {
            text: "\uf011",
            color: Tokyo.fg,
            visible: true,
        },
    ]
    hPad: 12
    tooltip: ""

    onClicked: button => {
        if (button === Qt.LeftButton && root.flyoutHost) {
            root.flyoutHost.toggleFor(root)
            root.flyoutHost.refreshAll()
        }
    }
}
