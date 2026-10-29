// AudioCard.qml — the audio card, hanging off the control centre's left edge.
//
// Not a flyout of its own: the drawer and this card live in the same popup
// surface (Island.qml), so opening audio opens the control centre with its card
// beside it — one window to dismiss, and the drawer already holds the keyboard.
// The card shares the drawer's top line and slides in with it.
//
// Sections: outputs, inputs, applications. A device row is how you *choose*
// that device, so only the default one carries volume and mute — a slider on a
// device nothing is routed through is a control with no effect. Every running
// playback stream gets its own slider and mute.
//
// No hover anywhere: rows react to keyboard focus (FocusRing) and a press, not
// to the pointer passing over them. Tab/arrows walk the controls, Enter/Space
// activate (Panel.qml), Escape closes.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property int cardWidth: 360

    implicitWidth: cardWidth
    implicitHeight: body.implicitHeight

    /// Device rows are only worth showing when they can carry volume: a node
    /// with no audio interface is still selectable, its controls just do not
    /// exist until the interface does.
    readonly property var outputs: Pipewire.nodes.values.filter(
        n => n && n.isSink && !n.isStream && n.audio)
    function inputList() {
        return Pipewire.nodes.values.filter(n => {
            if (!n || n.isStream) return false
            // The default source is kept whether or not it has an audio
            // interface: it is the mic you are actually recording from, and
            // hiding it would hide the only row that matters.
            if (n === Pipewire.defaultAudioSource) return true
            return n.audio && !n.isSink
        })
    }
    readonly property var inputs: root.inputList()
    readonly property var apps: Pipewire.nodes.values.filter(
        n => n && n.isStream && n.isSink && n.audio)

    // Nodes are only bound to PipeWire while something holds a reference.
    // Without this tracker every slider writes to an unbound node and nothing
    // happens.
    PwObjectTracker {
        objects: root.outputs.concat(root.inputs, root.apps)
    }

    function friendlyName(node) {
        if (!node) return ""
        const p = node.properties || {}
        return p["application.name"] || p["api.bluez5.device"]
                || node.description || node.nickname || node.name || "Unknown"
    }

    function setDefault(node, asInput) {
        if (!node) return
        if (asInput) Pipewire.preferredDefaultAudioSource = node
        else Pipewire.preferredDefaultAudioSink = node
    }

    /// Forwarded by Island.qml when the bar, not the popup, holds the keyboard.
    function handleKey(event) {
        body.handleKey(event)
    }

    // The drawer's card is part of the island; this one rides in the same
    // popup, so it carries its own fill, border and shadow.
    Rectangle {
        id: card
        anchors.fill: body
        z: -1
        radius: Tokyo.islandPanelRadius
        color: Tokyo.islandFill
        border.color: Tokyo.paneEdge
        border.width: 1

        RectangularShadow {
            anchors.fill: parent
            radius: parent.radius
            blur: Tokyo.flyoutShadowBlur
            offset: Qt.vector2d(0, Tokyo.flyoutShadowOffsetY)
            color: Tokyo.flyoutShadowColor
        }
    }

    Panel {
        id: body
        width: root.cardWidth
        gap: 2

        Text {
            width: parent.width
            text: "OUTPUT"
            color: Tokyo.blue
            topPadding: 2
            font { family: Tokyo.fontFamily; pixelSize: 9; bold: true; letterSpacing: 1.2 }
        }
        Repeater {
            model: root.outputs
            delegate: DeviceRow { required property var modelData; node: modelData; asInput: false }
        }

        Text {
            width: parent.width
            text: "INPUT"
            color: Tokyo.blue
            topPadding: 10
            font { family: Tokyo.fontFamily; pixelSize: 9; bold: true; letterSpacing: 1.2 }
        }
        Repeater {
            model: root.inputs
            delegate: DeviceRow { required property var modelData; node: modelData; asInput: true }
        }

        Text {
            width: parent.width
            text: "APPLICATIONS"
            color: Tokyo.blue
            topPadding: 10
            font { family: Tokyo.fontFamily; pixelSize: 9; bold: true; letterSpacing: 1.2 }
        }
        Repeater {
            model: root.apps
            delegate: AppRow { required property var modelData; node: modelData }
        }
        Text {
            width: parent.width
            visible: root.apps.length === 0
            text: "Nothing playing"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }
    }

    // ---------------- rows ----------------
    component DeviceRow: Rectangle {
        id: row
        required property var node
        required property bool asInput

        readonly property bool isDefault: row.node !== null && (row.asInput
            ? Pipewire.defaultAudioSource === row.node
            : Pipewire.defaultAudioSink === row.node)
        readonly property var audio: row.node && row.node.audio
                                       ? row.node.audio : null

        width: parent ? parent.width : 0
        height: 30
        radius: 6
        color: "transparent"

        // First, so the slider and the mute glyph paint (and take clicks) over
        // it. The ring is on the row, not on this area: selecting covers the
        // whole row and the ring should say so.
        MouseArea {
            id: pick
            anchors.fill: parent
            activeFocusOnTab: true
            function activate() { root.setDefault(row.node, row.asInput) }
            onClicked: activate()
        }
        FocusRing { visible: pick.activeFocus }

        Text {
            anchors {
                left: parent.left; leftMargin: 8
                right: row.isDefault ? meter.left : parent.right
                rightMargin: row.isDefault ? 8 : 8
                verticalCenter: parent.verticalCenter
            }
            text: root.friendlyName(row.node)
            elide: Text.ElideRight
            color: row.isDefault ? Tokyo.blue : Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: 11 }
        }

        // The controls exist only on the active device; a fixed-width strip
        // reserves their room on every row so names line up.
        Item {
            id: meter
            anchors { right: parent.right; rightMargin: 4
                      verticalCenter: parent.verticalCenter }
            // A zero-width Item does not clip its children: the slider and the
            // mute glyph would still paint, hanging off the row. Hide them.
            visible: row.isDefault && row.audio !== null
            width: 152
            height: 18

            VolumeSlider {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 92
                audio: row.audio
            }
            Text {
                anchors { left: parent.left; leftMargin: 100
                          verticalCenter: parent.verticalCenter }
                width: 32
                text: row.audio ? Math.round(row.audio.volume * 100) + "%" : ""
                color: row.audio && row.audio.muted ? Tokyo.dim : Tokyo.fg
                horizontalAlignment: Text.AlignRight
                font { family: Tokyo.fontFamily; pixelSize: 10 }
            }
            MuteGlyph {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                audio: row.audio
                isInput: row.asInput
            }
        }
    }

    component AppRow: Rectangle {
        id: row
        required property var node

        readonly property var audio: row.node && row.node.audio ? row.node.audio : null

        width: parent ? parent.width : 0
        height: 30
        radius: 6
        color: "transparent"

        Text {
            anchors {
                left: parent.left; leftMargin: 8
                right: rowMeter.left; rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: root.friendlyName(row.node)
            elide: Text.ElideRight
            color: Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: 11 }
        }

        Item {
            id: rowMeter
            anchors { right: parent.right; rightMargin: 4
                      verticalCenter: parent.verticalCenter }
            width: 152
            height: 18

            VolumeSlider {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 92
                audio: row.audio
            }
            Text {
                anchors { left: parent.left; leftMargin: 100
                          verticalCenter: parent.verticalCenter }
                width: 32
                text: row.audio ? Math.round(row.audio.volume * 100) + "%" : ""
                color: row.audio && row.audio.muted ? Tokyo.dim : Tokyo.fg
                horizontalAlignment: Text.AlignRight
                font { family: Tokyo.fontFamily; pixelSize: 10 }
            }
            MuteGlyph {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                audio: row.audio
            }
        }
    }

    component VolumeSlider: Item {
        id: vs
        property var audio: null

        implicitWidth: 92
        height: 18

        readonly property real value: vs.audio ? vs.audio.volume : 0

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Tokyo.bgHighlight
        }
        Rectangle {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: parent.width * Math.max(0, Math.min(1, vs.value))
            height: 4
            radius: 2
            color: vs.audio && vs.audio.muted ? Tokyo.dim : Tokyo.magenta
            Behavior on width {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            activeFocusOnTab: true
            onPressed: m => {
                forceActiveFocus()
                moveTo(m.x / width)
            }
            onPositionChanged: m => {
                if (pressed) moveTo(m.x / width)
            }
            Keys.onLeftPressed: nudge(-1)
            Keys.onRightPressed: nudge(1)
            function moveTo(v) {
                if (vs.audio) vs.audio.volume = Math.max(0, Math.min(1, v))
            }
            function nudge(direction) {
                if (vs.audio)
                    vs.audio.volume = Math.max(0, Math.min(1,
                                        vs.value + direction * 0.05))
            }
            FocusRing {}
        }
    }

    component MuteGlyph: Item {
        id: mg
        property var audio: null
        property bool isInput: false

        implicitWidth: 20
        implicitHeight: 18

        Text {
            anchors.centerIn: parent
            // Speaker off/on, or mic off/on: a mute button drawn as a speaker
            // on an input row lies about which side of the pipe it controls.
            text: !mg.audio ? ""
                  : (mg.audio.muted ? (mg.isInput ? "\uf131" : "\uf026")
                                    : (mg.isInput ? "\uf130" : "\uf028"))
            color: mg.audio && mg.audio.muted ? Tokyo.red : Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: 11 }
        }

        MouseArea {
            anchors.fill: parent
            activeFocusOnTab: true
            enabled: mg.audio !== null
            function activate() {
                if (mg.audio) mg.audio.muted = !mg.audio.muted
            }
            onClicked: activate()
            FocusRing {}
        }
    }
}
