// config-lite.qml — Lite bar with plugin system
//
// This is a plugin-based shell configuration.
// Load with: quickshell -c "config-lite"
// (Requires shell.qml symlink or config directory setup)

import QtQuick 2.15
import Quickshell 0.3
import Quickshell.Hyprland 0.3
import Quickshell.Io 0.3
import Quickshell.Wayland 0.3

ShellRoot {
    id: root
    
    // ===== Services (global, single instance) =====
    NotificationStore { id: notificationStore }
    
    // ===== Plugin Loader =====
    PluginLoader {
        id: plugins
        basePath: Quickshell.env("HOME") + "/.config/quickshell/ZSW-Quickshell/plugins/"
        
        onReady: {
            console.log("Plugins loaded:", plugins.list().join(", "))
        }
    }
    
    // ===== Bar (uses plugins) =====
    Bar {
        id: bar
        networkMonitor: null  // Could be injected from services
        brightness: null
        notifications: notificationStore
        
        // --- Left side ---
        // Workspaces pill
        Module {
            anchor: workspacesPillAnchor
            text: "WS"
            fg: Tokyo.fg
            hoverStyle: true
            onClicked: console.log("Workspaces clicked")
        }
        
        // Audio pill
        Module {
            anchor: audioPillAnchor
            text: "🔊"
            fg: Tokyo.cyan
            hoverStyle: true
            onClicked: console.log("Audio clicked")
        }
        
        // Tray
        Item {
            visible: false  // Placeholder
        }
        
        // --- Center ---
        // Clock pill (from plugin)
        Clock {
            anchor: clockPillAnchor
        }
        
        // --- Right side ---
        Sys { }
        NotificationBell { store: notificationStore }
        Settings { }
    }
    
    // ===== Island (launcher/control center) =====
    Island {
        id: island
        capsuleWidth: Tokyo.launcherWidth
        
        Quick {
            // Uses plugins for QuickPanel content
        }
    }
    
    // ===== Anchors for flyouts =====
    // Clock flyout anchor
    Item {
        id: clockPillAnchor
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
        }
        width: 1; height: 1
    }
    
    Anchor {
        id: workspacesPillAnchor
    }
    
    Anchor {
        id: audioPillAnchor
    }
}