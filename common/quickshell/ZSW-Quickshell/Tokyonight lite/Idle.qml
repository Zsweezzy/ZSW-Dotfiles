// Idle.qml — the idle daemon: lock the session and turn the panel off.
//
// Two IdleMonitors rather than one timer: the thresholds are independent, so
// "screen off at 5, lock at 10" is two watchers, not one timer that has to
// remember where it is. `respectInhibitors` is what keeps a fullscreen video
// from locking the session — mpv and games take a Wayland idle inhibitor.
//
// hypridle is not running alongside this; one daemon owns the idle protocol.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    /// hyprctl is the only way to blank the panel; Quickshell has no DPMS
    /// service. A failed dispatch is harmless (the panel stays on).
    Process {
        id: dpms
        command: ["hyprctl", "dispatch", "dpms", "off"]
    }

    IdleMonitor {
        id: lockIdle
        enabled: Settings.lockIdleMinutes > 0 && !Session.locked
        timeout: Math.max(1, Settings.lockIdleMinutes) * 60 * 1000
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle && !Session.locked) Session.lock()
        }
    }

    IdleMonitor {
        id: dpmsIdle
        enabled: Settings.dpmsIdleMinutes > 0
        timeout: Math.max(1, Settings.dpmsIdleMinutes) * 60 * 1000
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) dpms.running = true
        }
    }
}
