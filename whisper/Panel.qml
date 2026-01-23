import "root:/"
import "root:/modules/common"
import "root:/modules/common/widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: voiceScope
    property bool isListening: false
    
    Variants {
        id: voiceVariants
        model: Quickshell.screens.filter(s => Hyprland.monitorFor(s).id === Hyprland.focusedMonitor?.id)
        PanelWindow {
            id: root
            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            screen: modelData
            visible: voiceScope.isListening

            WlrLayershell.namespace: "quickshell:voice"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1  // Don't reserve space, but appear on top
            color: "transparent"

            // Set mask to ensure proper overlay behavior
            mask: Region {
                item: voiceScope.isListening ? iconContainer : null
            }
            HyprlandWindow.visibleMask: Region {
                item: voiceScope.isListening ? iconContainer : null
            }

            anchors {
                left: true
                right: true
                bottom: true
            }

            // Container to center the audio wave - floats above bottom with padding
            Item {
                id: iconContainer
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 30  // Add some padding from the bottom
                }
                width: audioWaveRow.width + 20  // Padding for background
                height: 40
                z: 999  // Ensure it's on top

                // Rounded background
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#000000"
                    opacity: 0.85
                }

                // Audio wave bars (equalizer effect)
                Row {
                    id: audioWaveRow
                    anchors.centerIn: parent
                    spacing: 3
                    height: parent.height

                    Repeater {
                        model: 18  // Number of bars (reduced for smaller size)

                        Rectangle {
                            width: 2.5
                            height: 6
                            radius: 1.25
                            color: Appearance.colors.colPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.7

                            property real baseHeight: 6
                            property real maxHeight: 28
                            property real animDelay: index * 50  // Stagger the animations (increased)
                            property real speed: 300 + (index % 3) * 100  // Vary speed per bar (slower)

                            SequentialAnimation on height {
                                running: voiceScope.isListening
                                loops: Animation.Infinite
                                PauseAnimation { duration: animDelay }
                                NumberAnimation {
                                    from: baseHeight
                                    to: baseHeight + (maxHeight * (0.3 + (index % 5) * 0.15))
                                    duration: speed
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: baseHeight + (maxHeight * (0.1 + (index % 3) * 0.1))
                                    duration: speed * 0.8
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: baseHeight + (maxHeight * (0.5 + (index % 7) * 0.1))
                                    duration: speed * 1.2
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: baseHeight
                                    duration: speed * 0.6
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            // Opacity animation for depth effect
                            SequentialAnimation on opacity {
                                running: voiceScope.isListening
                                loops: Animation.Infinite
                                PauseAnimation { duration: animDelay }
                                NumberAnimation {
                                    from: 0.5
                                    to: 1.0
                                    duration: speed
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: 0.7
                                    duration: speed * 0.8
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: 0.5
                                    duration: speed * 0.6
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: hyprvoiceProcess
        command: ["bash", "-c", "/home/Usuario/.local/bin/hyprvoice toggle > /tmp/hypervoice.log 2>&1"]
    }

    // Function to toggle listening state
    function toggle() {
        voiceScope.isListening = !voiceScope.isListening
        hyprvoiceProcess.startDetached()
    }

    // IPC Handler to allow calling from Hyprland keybindings
    IpcHandler {
        target: "voice"

        function toggle() {
            voiceScope.toggle()
        }
    }

    // Global shortcut for $mod + R (alternative way, may also work)
    GlobalShortcut {
        name: "voiceToggle"
        description: qsTr("Toggle voice recognition indicator")

        onPressed: {
            voiceScope.toggle()
        }
    }
}
