// shell-lite-plugin.qml — lite shell with plugin architecture
//
// Plugin-based shell configuration.
// Load with: quickshell -c "shell-lite-plugin"
//
// This config demonstrates the plugin system. Widgets are loaded
// as plugins from the plugins/ directory.

import QtQuick 2.15
import Quickshell 0.3
import Quickshell.Hyprland 0.3
import Quickshell.Io 0.3
import Quickshell.Wayland 0.3

ShellRoot {
    id: root
    
    // ===== Global Services =====
    // These are shared state singletons, loaded once
    
    NotificationStore { id: notificationStore }
    
    // ===== Plugin Components =====
    // Load each plugin's QML component. The plugin's manifest.json
    // specifies the file to load as the "entry" point.
    
    // Clock pill (plugins/clock)
    Component {
        id: clockComponent
        source: "plugins/clock/Widget.qml"
    }
    
    // Workspaces pill (plugins/workspaces)  
    Component {
        id: workspacesComponent
        source: "plugins/workspaces/Widget.qml"
    }
    
    // Audio pill (plugins/audio)
    Component {
        id: audioComponent
        source: "plugins/audio/Widget.qml"
    }
    
    // Clock flyout (plugins/clock-flyout)
    Component {
        id: clockFlyoutComponent
        source: "plugins/clock-flyout/Widget.qml"
    }
    
    // ===== Bar Window =====
    Variants {
        id: barRoot
        model: Quickshell.screens
        
        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData
            
            anchors { top: true; left: true; right: true }
            implicitHeight: Tokyo.barHeight + Tokyo.shadowPad
            exclusiveZone: Tokyo.barHeight
            color: "transparent"
            
            // ===== Toolbar (Island capsule) =====
            Island {
                id: island
                screen: win.screen
                capsuleWidth: root.capsuleWidth
                
                // Left side: workspace navigation
                Workspaces {
                    sourceComponent: workspacesComponent
                    screen: win.screen
                }
                
                // Center: clock
                Clock {
                    id: clockPill
                    sourceComponent: clockComponent
                    flyoutHost: clockFlyoutComponent
                    anchor: clockAnchor
                }
                
                // Right side: audio and quick controls
                Audio {
                    sourceComponent: audioComponent
                    flyoutHost: audioFlyoutHost
                }
                
                // Quick settings panel
                Quick {
                    id: quickPanel
                }
            }
            
            // ===== Toast Notifications =====
            Item {
                id: toastAnchor
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: Tokyo.barHeight + 8
                    rightMargin: Tokyo.edgeGap + 3
                }
                width: 0; height: 0
            }
            
            Toast {
                store: notificationStore
                anchorItem: toastAnchor
            }
        }
    }
    
    // ===== Anchor References =====
    // Used for flyout positioning
    Item {
        id: clockAnchor
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
        }
        width: 1; height: 1
    }
    
    // ===== Capsule Width Animation =====
    Binding {
        target: root
        property: "capsuleWidth"
        value: island.capsuleWidth
        when: win.screen.name === Hyprland.focusedMonitor?.name
    }
    
    readonly property real capsuleWidth: Tokyo.launcherWidth
}