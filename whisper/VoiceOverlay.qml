import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

Scope {
    id: voiceScope

    property bool isListening: false

    // Render on the focused monitor (same intent as your original module)
    Variants {
        model: Quickshell.screens.filter(s => Hyprland.monitorFor(s).id === Hyprland.focusedMonitor?.id)

        PanelWindow {
            id: root
            required property var modelData

            screen: modelData
            visible: voiceScope.isListening
            color: "transparent"

            WlrLayershell.namespace: "noctalia:whisper"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1

            anchors {
                left: true
                right: true
                bottom: true
            }

            Item {
                id: iconContainer
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 30
                }

                width: audioWaveRow.width + 20
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#000000"
                    opacity: 0.85
                }

                Row {
                    id: audioWaveRow
                    anchors.centerIn: parent
                    spacing: 3
                    height: parent.height

                    Repeater {
                        model: 18

                        Rectangle {
                            width: 2.5
                            height: 6
                            radius: 1.25
                            color: Color.mPrimary
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.7

                            property real baseHeight: 6
                            property real maxHeight: 28
                            property real animDelay: index * 50
                            property real speed: 300 + (index % 3) * 100

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
}

