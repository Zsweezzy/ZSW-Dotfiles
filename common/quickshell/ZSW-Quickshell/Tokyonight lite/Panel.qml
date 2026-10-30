import QtQuick

// Base for an island flyout. The panel owns its width (`implicitWidth`), and
// Island.qml reads that same value for the capsule header, so a pill can never
// disagree with the card under it. Adding a module means adding its panel and
// no width entry anywhere else.
//
// It also owns keyboard navigation: Tab/Shift+Tab are Qt's focus chain (every
// control opts in with `activeFocusOnTab`), the arrows step through the same
// chain, and Enter/Space call the focused control's `activate()`. A panel that
// wants keyboard behaviour only has to wrap its click handler in that function.
Item {
    id: root

    property real padH: Tokyo.panelPadH
    property real padV: Tokyo.panelPadV
    /// Gap between the body's children. Most panels use the house value; the
    /// audio card packs rows tighter.
    property real gap: Tokyo.panelGap

    /// Screen the panel is on, set by Island's Loader. Null offscreen (the
    /// test probe), where a panel keeps its declared implicitWidth.
    property var hostScreen: null

    default property alias content: body.data

    implicitHeight: body.implicitHeight + root.padV * 2
    // A flyout declares the narrowest width it works at; the island puts it in
    // a card that is at least as wide as the capsule's pill row, so the item
    // fills that card instead of leaving a dead strip beside it. Offscreen (no
    // parent) it stays at its own width, which is what the probe checks.
    width: parent ? parent.width : implicitWidth

    Keys.onPressed: event => root.handleKey(event)

    /// Key handling as a function so the bar can drive a panel whose popup
    /// could not take an xdg grab (opened from a keybind, not a click).
    function handleKey(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            if (root.activateFocused()) event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
            root.stepFocus(true)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
            root.stepFocus(false)
            event.accepted = true
        }
    }

    /// Focus the first control in this panel. Island.qml calls it after a
    /// keybind open, because the newly loaded panel is the one that owns focus.
    /// A pointer open does not call it: the ring on that control read as a
    /// permanent selection box the user never asked for.
    function focusFirst() {
        let item = root.nextItemInFocusChain(true)
        for (let i = 0; i < 200 && item; i++) {
            if (item.activeFocusOnTab) {
                item.forceActiveFocus()
                return
            }
            item = item.nextItemInFocusChain(true)
        }
    }

    /// Move to the next/previous control. Items without `activeFocusOnTab`
    /// (the card, the panel itself) are skipped rather than focused.
    function stepFocus(forward) {
        let item = root.Window.activeFocusItem
        if (!item) item = root
        for (let i = 0; i < 200; i++) {
            const next = item.nextItemInFocusChain(forward)
            if (!next || next === item) return
            if (next.activeFocusOnTab) {
                next.forceActiveFocus()
                return
            }
            item = next
        }
    }

    /// Enter/Space on the focused control. Returns false when focus is not on
    /// anything activatable, so the key keeps travelling up the tree.
    function activateFocused() {
        const item = root.Window.activeFocusItem
        if (!item || typeof item.activate !== "function") return false
        item.activate()
        return true
    }

    Column {
        id: body
        x: root.padH
        y: root.padV
        width: root.width - root.padH * 2
        spacing: root.gap
    }
}
