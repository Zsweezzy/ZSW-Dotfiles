import QtQuick
import QtQuick.Layouts

Panel {
    id: root

    /// The Updates module in the bar; it owns the upgrade process.
    property var updatesModule: null

    readonly property var packages: root.updatesModule ? root.updatesModule.packages : []
    readonly property bool updating: root.updatesModule ? root.updatesModule.updating : false
    readonly property string status: root.updatesModule ? root.updatesModule.status : ""

    implicitWidth: 340

    RowLayout {
        width: parent.width

        Text {
            text: "Updates"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 12 }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.packages.length + " pending"
            color: Tokyo.cyan
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }
    }

    Column {
        width: parent.width
        spacing: 4

        Repeater {
            model: root.packages.slice(0, 8)
            delegate: Text {
                required property string modelData
                width: parent.width
                text: modelData
                color: Tokyo.fg
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 11 }
            }
        }
        Text {
            visible: root.packages.length > 8
            text: "+" + (root.packages.length - 8) + " more"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }
    }

    Rectangle {
        width: parent.width
        height: 30
        radius: Tokyo.pillRadius
        color: root.updating ? Tokyo.bgHighlight : Tokyo.activeTint

        Text {
            anchors.centerIn: parent
            text: root.updating ? "Updating…" : "Update all"
            color: root.updating ? Tokyo.dim : Tokyo.cyan
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.updating && root.packages.length > 0
            onClicked: if (root.updatesModule) root.updatesModule.startUpdate()
        }
    }

    // One line of live pacman output, or why the run failed.
    Text {
        width: parent.width
        visible: root.status !== ""
        text: root.status
        color: root.status.startsWith("Failed") ? Tokyo.red : Tokyo.dim
        elide: Text.ElideRight
        font { family: Tokyo.fontFamily; pixelSize: 10 }
    }
}
