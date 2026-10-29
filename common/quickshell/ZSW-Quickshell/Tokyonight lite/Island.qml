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
    /// True on the monitor the launcher window is on, while it is mapped.
    property bool launcherOpen: false
    onLauncherOpenChanged: if (root.launcherOpen) {
        root.close()
        root.audioOpen = false
    }
    /// True on the monitor the theme picker is on, while it is mapped.
    property bool pickerOpen: false
    /// True on the monitor the clipboard picker is open on. The picker is an
    /// overlay window, so an open flyout would otherwise sit on top of its
    /// field; opening it closes the flyout.
    property bool clipboardOpen: false
    onClipboardOpenChanged: if (root.clipboardOpen) root.close()
    /// True on the monitor the polkit prompt is up. It is modal, so it also
    /// closes any flyout that was open underneath.
    property bool polkitOpen: false
    onPolkitOpenChanged: if (root.polkitOpen) root.close()
    /// the shell-wide notification store (ShellRoot), for the bell and centre
    property var store: null

    /// Module whose flyout is open, or null. The module owns the panel
    /// component and the panel owns its width — see Module.qml and Panel.qml.
    property var panelModule: null

    /// True while the audio card is hanging off the drawer's left edge. One
    /// popup, so it needs no lifetime of its own.
    property bool audioOpen: false

    /// Any card is on screen. Bar.qml keeps the whole island out of the way
    /// over a fullscreen window until one of these asks for it.
    readonly property bool anyOpen: popup.visible || audioOpen || launcherOpen
                                    || pickerOpen || clipboardOpen || polkitOpen

    /// The audio card is part of the drawer's surface, so one surface means one
    /// keyboard: while the popup is mapped the bar takes it (see Bar.qml), an
    /// xdg_popup can only receive keys while its parent surface can.
    readonly property bool keyboardActive: popup.visible

    /// Keys reach the island itself only when the popup could not take a grab
    /// (opened from Super+Tab/N/A, where there is no pointer serial). The bar
    /// then keeps the keyboard and this forwards to whichever card has focus.
    focus: root.keyboardActive
    Keys.onPressed: event => root.handleKey(event)

    function focusIn(item) {
        let it = root.Window.activeFocusItem
        while (it) {
            if (it === item) return true
            it = it.parent
        }
        return false
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
            return
        }
        if (audioLoader.item && root.focusIn(audioLoader.item))
            audioLoader.item.handleKey(event)
        else if (panelLoader.item) panelLoader.item.handleKey(event)
    }

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
    /// The audio card's share of the popup: the drawer keeps its width and the
    /// card hangs off its left edge, sharing its top line.
    readonly property real audioWidth: root.audioOpen && audioLoader.item
                                       ? audioLoader.item.implicitWidth : 0
    readonly property real audioHeight: root.audioOpen && audioLoader.item
                                        ? audioLoader.item.implicitHeight : 0
    readonly property real audioExtra: root.audioWidth > 0
                                       ? Tokyo.panelGap + root.audioWidth : 0

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

    function open(module, byKeyboard) {
        closeTimer.stop()
        root.closing = false
        root.panelModule = module
        // A keybind has no pointer serial, so xdg_popup cannot be grabbed:
        // asking for the grab just makes the surface fail to map. In that mode
        // the bar keeps the keyboard (Bar.qml) and forwards keys here.
        popup.grabFocus = !byKeyboard
        popup.visible = true
        Qt.callLater(() => {
            if (panelLoader.item) panelLoader.item.focusFirst()
            else card.forceActiveFocus()
        })
    }

    function toggle(module, byKeyboard) {
        if (!popup.visible) root.open(module, byKeyboard)
        else if (root.panelModule === module) root.close()
        else root.switchTo(module)
    }

    /// Keyboard entry point (Super+Tab through shell.qml's IpcHandler): the
    /// capsule's own flyout, the same one its pills open.
    function toggleFlyout(byKeyboard) {
        root.toggle(quickPill, byKeyboard)
    }

    /// Super+N: the notification centre.
    function toggleNotifications(byKeyboard) {
        root.toggle(bell, byKeyboard)
    }

    /// Super+A and the audio pill: the audio card hangs off the control centre,
    /// so it brings the drawer with it. Toggling it off leaves the drawer up.
    function toggleAudio(byKeyboard) {
        if (root.audioOpen) {
            root.audioOpen = false
            return
        }
        if (!popup.visible) root.open(quickPill, byKeyboard)
        else if (root.panelModule !== quickPill) root.switchTo(quickPill)
        root.audioOpen = true
    }

    // Same pill row, new panel: the card morphs its width/height and the two
    // contents crossfade. Nothing retracts and the surface never unmaps.
    function switchTo(module) {
        closeTimer.stop()
        root.closing = false
        root.audioOpen = false
        root.outgoingModule = root.panelModule
        root.morphProgress = 0
        root.panelModule = module
        morphAnim.restart()
    }

    function close() {
        if (!popup.visible || root.closing) return
        root.closing = true
        root.audioOpen = false
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
        easing.type: Easing.OutExpo
    }

    // The prompt card joins the capsule's bottom edge, so while it is up the
    // capsule's shadow has to stop at that edge: this window stacks over the
    // prompt's, and the 12px of shadow below the capsule would otherwise
    // darken the card's top and break the join. The prompt draws the rest of
    // the shadow along the card.
    Item {
        x: capsule.x - Tokyo.shadowPad
        y: capsule.y - Tokyo.shadowPad
        width: capsule.width + Tokyo.shadowPad * 2
        height: capsule.height + Tokyo.shadowPad
                + (root.polkitOpen ? 0 : Tokyo.shadowBlur + Tokyo.shadowOffsetY)
        clip: root.polkitOpen

        RectangularShadow {
            x: Tokyo.shadowPad
            y: Tokyo.shadowPad
            width: capsule.width
            height: capsule.height
            radius: capsule.radius
            blur: Tokyo.shadowBlur
            offset: Qt.vector2d(0, Tokyo.shadowOffsetY)
            color: Tokyo.shadowColor
        }
    }

    Rectangle {
        id: capsule
        anchors.verticalCenter: parent.verticalCenter
        // The launcher, picker and polkit cards are exactly as wide as this;
        // widening the capsule while one is open lets the card's square top
        // join the capsule's square bottom edge instead of poking out under a
        // narrow pill.
        width: root.polkitOpen ? Tokyo.polkitWidth
               : root.pickerOpen ? Tokyo.pickerWidth
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
                          : (root.launcherOpen || root.pickerOpen || root.polkitOpen)
                            ? Tokyo.expandDuration : Tokyo.collapseDuration
                easing.type: Easing.OutExpo
            }
        }
        height: Tokyo.islandHeight
        radius: height / 2
        // While a panel is open the capsule is the panel's header, so its
        // bottom corners square off into the card (which is at least as wide).
        // The launcher's window carries the same header shape.
        bottomLeftRadius: popup.visible || root.launcherOpen || root.pickerOpen
                          || root.polkitOpen ? 0 : height / 2
        bottomRightRadius: popup.visible || root.launcherOpen || root.pickerOpen
                           || root.polkitOpen ? 0 : height / 2
        Behavior on bottomLeftRadius {
            NumberAnimation { duration: Tokyo.collapseDuration; easing.type: Easing.OutExpo }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: Tokyo.collapseDuration; easing.type: Easing.OutExpo }
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
                hPad: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(quickPill)
            }

            // Only visible while a player has a track; a paused player keeps
            // the pill, a closed one takes it away. Its own flyout is gone:
            // the card the capsule opens holds now-playing and volume.
            Media {
                id: mediaPill
                flat: true
                hPad: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(quickPill)
            }

            // The audio pill opens the advanced side panel, not the quick
            // card: per-device, per-app volume and routing live there.
            Audio {
                id: audioPill
                flat: true
                hPad: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggleAudio()
            }

            // Everything the bar shows shares one flyout: separate pills would
            // push the capsule past the edge, and a clock card next to a
            // network card made two places to look for one monitor's state.
            Quick {
                id: quickPill
                clockModule: clockPill
                mediaModule: mediaPill
                audioModule: audioPill
                flat: true
                hPad: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle(quickPill)
            }

            // The bell is the centre's entry and the badge its unread count.
            // Both live in this shell, so there is no second process to poll
            // and no layer event to chase.
            Item {
                id: bellHost
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight

                readonly property int unread: root.store ? root.store.unread : 0

                Module {
                    id: bell
                    text: "󰂚"
                    flat: true
                    hPad: 0
                    panel: Component {
                        NotificationsPanel {
                            store: root.store
                        }
                    }
                    onClicked: root.toggle(bell)
                }

                Rectangle {
                    visible: bellHost.unread > 0
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
                        text: bellHost.unread > 99 ? "99+"
                              : String(bellHost.unread)
                        color: Tokyo.islandFill
                        font { family: Tokyo.fontFamily; pixelSize: 8; bold: true }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: popup
        color: "transparent"
        visible: false
        // The card is a keyboard surface: Tab/arrows move between its controls.
        // It only works while the bar holds the keyboard (Bar.qml).
        grabFocus: true
        implicitWidth: root.surfaceWidth + Tokyo.flyoutShadowPad * 2 + root.audioExtra
        implicitHeight: Math.max(1, Math.max(root.surfaceHeight, root.audioHeight)
                                    + Tokyo.flyoutShadowPad)

        // An xdg_popup dismisses itself on an outside click, and that write
        // drops the binding on `visible` — so the state has to follow the
        // window, not the other way round. A morph that is still running lands
        // here too, so its outgoing panel is dropped with the rest.
        onVisibleChanged: if (!visible) {
            root.panelModule = null
            root.outgoingModule = null
            root.audioOpen = false
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

        // The popup is centred under the capsule. Growing it to the left would
        // drag the drawer with it, so the anchor rect takes the card's share on
        // the right: the popup shifts left by exactly what it gained, and the
        // drawer stays where it is.
        anchor.margins.right: root.audioExtra

        // The flyout's shadow, in the transparent room the popup keeps around
        // the card. A plain rounded rect blurred by MultiEffect, not
        // RectangularShadow: that one draws its shape inset from its item, so
        // the fade starts a dozen pixels away from the card and the gap reads
        // as a hard line. The rect is the card grown by the blur, so the fade
        // is already at zero when it reaches the item's edge.
        Rectangle {
            x: card.x - Tokyo.flyoutShadowBlur
            y: card.y - Tokyo.flyoutShadowBlur + Tokyo.flyoutShadowOffsetY
            width: card.width + Tokyo.flyoutShadowBlur * 2
            height: card.height + Tokyo.flyoutShadowBlur * 2
            radius: card.radius + Tokyo.flyoutShadowBlur
            color: Tokyo.flyoutShadowColor
            visible: card.reveal > 0
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: Tokyo.flyoutShadowBlur
            }
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
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutExpo }
            }
            // Never 0: closing nulls panelModule, the loader drops its item and
            // this binding collapses in the same commit — a 0-height xdg_popup
            // buffer is a Wayland protocol error and kills the process.
            height: Math.max(1, root.panelHeight)
            Behavior on height {
                enabled: root.outgoingModule !== null
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutExpo }
            }
            // The surface holds the larger of the two panels while morphing, so
            // the card is centred in it rather than left-aligned (the popup is
            // centred under the capsule). The audio card, when it is up, owns
            // the left strip; the margin on the popup shifts the whole surface
            // left by that same amount, so the drawer does not move on screen.
            // The pad on both sides is the room the shadow needs.
            x: Tokyo.flyoutShadowPad + root.audioExtra + (root.surfaceWidth - width) / 2
            // Drawer: the popup surface is already this tall, so the whole card
            // slides down from behind the capsule, and back up on close.
            // Animating the surface's own height instead resizes it mid-map and
            // renders a sliver. Multiplying by `height` keeps the offset right
            // if the panel's height lands a frame late.
            property real reveal: popup.visible && !root.closing ? 1 : 0
            Behavior on reveal {
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutExpo }
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
                // A panel sizes itself from the screen it is on (the control
                // centre is half the monitor wide), so it gets the island's.
                onLoaded: {
                    if (!panelLoader.item) return
                    panelLoader.item.hostScreen = root.screen
                    panelLoader.item.focusFirst()
                }
                // Rides the slide; during a morph the slide is already at 1 and
                // the crossfade takes over.
                opacity: card.reveal * (root.outgoingModule !== null ? root.morphProgress : 1)
            }

        }

        // The audio card, in the drawer's own surface: beside the status box the
        // volume pill lives in (the drawer's left column), sharing the top line
        // and riding the same slide. Loaded only while open so the panel's
        // `focusFirst` cannot run on a hidden card.
        Loader {
            id: audioLoader
            active: root.audioOpen
            // The popup grew left by exactly this strip (audioExtra on the
            // popup's right margin keeps the drawer still), so the card hugs
            // the popup's left pad and the gap falls between it and the drawer.
            x: Tokyo.flyoutShadowPad
            property real reveal: card.reveal
            y: -height * (1 - reveal)
            sourceComponent: Component { AudioCard {} }
        }
    }
}
