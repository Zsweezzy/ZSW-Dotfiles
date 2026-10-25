pragma Singleton
// AudioStates.qml — audio-panel state that must survive a reload.
// A plain `property bool overboost` inside AudioFlyout resets to false every
// time the config reloads, so the boosted 150% ceiling would forget itself
// while the wheel in Audio.qml and the flyout sliders silently disagreed.
// PersistentProperties keys on reloadableId and restores the value.
import QtQuick
import Quickshell

Singleton {
    id: root

    PersistentProperties {
        id: persist
        reloadableId: "audioStates"
        property bool overboost: false
    }

    /// callers read and write AudioStates.overboost; the mirror keeps the
    /// PersistentProperties copy in sync
    property bool overboost: persist.overboost
    onOverboostChanged: {
        if (root.overboost !== persist.overboost) persist.overboost = root.overboost
    }
}