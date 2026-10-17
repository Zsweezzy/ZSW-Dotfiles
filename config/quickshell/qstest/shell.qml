import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    QtObject {
        id: lt
        property string noNl: "?"
        property string withNl: "?"
        property string buf: ""
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            anchors.top: true
            anchors.left: true
            implicitHeight: 200
            implicitWidth: 700
            color: "#000000"
            Rectangle {
                anchors.fill: parent
                color: "#14141c"
                Column {
                    x: 4; y: 4; spacing: 10
                    Text { text: "\ue266 12% 2/24GiB"; color: "#9d7cd8"; font { family: "JetBrains Mono Nerd Font"; pixelSize: 13 } }
                    Text { text: "\ue266" + lt.noNl; color: "#9d7cd8"; font { family: "JetBrains Mono Nerd Font"; pixelSize: 13 } }
                    Text { text: "\ue266" + lt.withNl; color: "#9d7cd8"; font { family: "JetBrains Mono Nerd Font"; pixelSize: 13 } }
                    Text { text: "buf=" + lt.buf; color: "#9ece6a"; font { family: "monospace"; pixelSize: 16 } }
                }
            }
        }
    }
    Process {
        command: ["/home/maxii/.config/waybar/gpu.sh"]
        running: true
        stdout: SplitParser {
            onRead: msg => lt.noNl = msg
        }
    }
    Process {
        command: ["sh", "-c", "printf ' 12% 2/24GiB\\n'"]
        running: true
        stdout: SplitParser {
            onRead: msg => lt.withNl = msg
        }
    }
}