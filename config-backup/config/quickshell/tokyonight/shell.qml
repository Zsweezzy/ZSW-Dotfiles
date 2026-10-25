import Quickshell

ShellRoot {
    // One daemon for the whole shell: NotificationServer claims
    // org.freedesktop.Notifications, and a second claim from another bar
    // window's copy would simply fail, so the server has to live outside the
    // per-monitor Variants in Bar.qml.
    NotificationStore { id: notificationStore }

    Bar {
        notifications: notificationStore
    }
}
