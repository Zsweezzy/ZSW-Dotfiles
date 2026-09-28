// QuadCell.qml — one titled cell of the clock flyout.
//
// The two cells only share a frame: title, rule, padding, and an area for the
// body. Keeping the frame here (instead of two hand-rolled panels) is what makes
// them line up — both panes then have identical insets, so the rules and the
// text baselines agree across the pair.
//
// Children go into `body`; anything meant to sit at the right end of the title
// row (the timers pane's STOP ALL) goes into `headerExtra`:
//
//   QuadCell {
//       title: "UPTIME"
//       headerExtra: PillButton { text: "…" }
//       Text { … }        // body
//   }
//
// Deliberately anchored, never a Column: Qt can polish a positioner before all
// of its children exist and never polish it again, which leaves every child
// stacked at y=0 (see TimerCreator.qml for the full story).
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    /// children of this cell, placed under the title rule
    default property alias body: bodyHolder.data
    /// children pinned to the right of the title row
    property alias headerExtra: headerSlot.data

    property string title: ""
    property color accent: Tokyo.blue

    readonly property real pad: 10
    readonly property real headerH: 14
    readonly property real gap: 8

    implicitWidth: 214
    implicitHeight: 176
    radius: Tokyo.pillRadius
    // `Tokyo.pane`, not bg: a cell in bg (#1e2030) is darker than the panel's
    // own fill, so the pair read as two black windows punched through the
    // widget rather than two cards sitting on it. The pane is a thin indigo wash
    // over that fill instead — same family as the pill, one step up.
    color: Tokyo.pane
    border.color: Tokyo.paneEdge
    border.width: 1

    // ---------- title row ----------
    RowLayout {
        id: headerRow
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: root.pad; rightMargin: root.pad; topMargin: root.pad
        }
        height: root.headerH
        spacing: 6

        Text {
            text: root.title
            color: root.accent
            font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
            Layout.alignment: Qt.AlignVCenter
        }
        // pushes headerExtra to the far edge without ending the layout, so the
        // spacer cannot accidentally take part in the title's sizing
        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }

        // A nested layout reports its own implicit size, so this collapses to
        // nothing when a cell adds no headerExtra.
        RowLayout {
            id: headerSlot
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Rectangle {
        id: headerRule
        anchors {
            left: parent.left; right: parent.right
            top: headerRow.bottom; topMargin: root.gap
            leftMargin: root.pad; rightMargin: root.pad
        }
        height: 1
        color: Tokyo.hairline
    }

    // ---------- body ----------
    Item {
        id: bodyHolder
        anchors {
            left: parent.left; right: parent.right
            top: headerRule.bottom; bottom: parent.bottom
            leftMargin: root.pad; rightMargin: root.pad
            topMargin: root.gap; bottomMargin: root.pad
        }
    }
}
