// NotificationStore.qml — the notification daemon behind the toasts. One
// instance for the whole shell, created in shell.qml.
//
// Declaring a `NotificationServer` is what takes the org.freedesktop.Notifications
// bus name. While something else holds it — swaync, mako, dunst, or the full
// config — this server simply never sees a notification and the toasts stay
// empty. Only one daemon can be the daemon.
//
// Slimmer than the full config's store of the same name on purpose: there is
// no notification centre in this tree, so there is no history log, no unread
// count and no rewrite(). The toasts need exactly two things from a store —
// the `newNotification` signal and the icon-name map NotifyIcon reads.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// A Scope and not a QtObject: it holds a Poll and a NotificationServer as
// children, and QtObject has no default property to put them in.
Scope {
    id: root

    /// A notification has arrived, carrying the daemon's own object. The toasts
    /// listen to this, because a toast needs the live object to dismiss and to
    /// run its default action.
    signal newNotification(var n)

    // ---------- icon names ----------
    /// icon name -> absolute path of the asset the theme would pick for a 40px
    /// box. Built once by scripts/notify-icons.py, which does the freedesktop
    /// lookup that Qt 6 no longer exposes to QML.
    property var icons: ({})

    function iconFor(name) {
        if (name === undefined || name === null || String(name) === "") return ""
        const hit = root.icons[String(name)]
        return hit !== undefined ? hit : ""
    }

    Poll {
        id: iconReader
        command: [Tokyo.scriptDir + "/notify-icons.py", "40"]
        interval: 600000
        onResult: line => {
            try {
                root.icons = JSON.parse(line)
            } catch (e) {
                root.icons = ({})
            }
        }
    }

    // ---------- the daemon ----------
    NotificationServer {
        // Hold on to notifications across a config reload, so a reload does not
        // silently drop whatever was on screen.
        keepOnReload: true
        // The caps are what these toasts actually honour. Declaring a
        // capability the renderer ignores is worse than not declaring it: the
        // client picks its behaviour from what the server says it supports.
        persistenceSupported: false
        bodySupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false
        onNotification: n => root.newNotification(n)
    }
}
