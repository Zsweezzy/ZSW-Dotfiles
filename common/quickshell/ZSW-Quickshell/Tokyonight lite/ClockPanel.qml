import QtQuick

Panel {
    id: root

    property var now: new Date()

    implicitWidth: 300

    Text {
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 40; bold: true; letterSpacing: 1 }
    }
    Text {
        text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
        color: Tokyo.dim
        font { family: Tokyo.fontFamily; pixelSize: 12 }
    }

    Column {
        width: parent.width
        spacing: 6

        Text {
            text: Qt.formatDateTime(root.now, "MMMM yyyy")
            color: Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }

        Row {
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text {
                    required property string modelData
                    width: 36
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Tokyo.islandDim
                    font { family: Tokyo.fontFamily; pixelSize: 11 }
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7

            Repeater {
                model: 42

                delegate: Item {
                    required property int index

                    readonly property int day: index - root.firstOffset(root.now) + 1
                    readonly property bool inMonth: day >= 1 && day <= root.daysInMonth(root.now)
                    readonly property bool today: inMonth && day === root.now.getDate()

                    width: 36
                    height: 24
                    visible: inMonth

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 11
                        color: today ? Tokyo.activeTint : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: day
                            color: today ? Tokyo.blue : Tokyo.fg
                            font {
                                family: Tokyo.fontFamily; pixelSize: 11
                                bold: today
                            }
                        }
                    }
                }
            }
        }
    }

    /// Monday-first offset of the 1st of the month, and the month's length.
    function firstOffset(d) {
        return (new Date(d.getFullYear(), d.getMonth(), 1).getDay() + 6) % 7
    }
    function daysInMonth(d) {
        return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
    }
}
