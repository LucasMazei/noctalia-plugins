import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    // Required by Noctalia panel entrypoint
    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 340 * Style.uiScaleRatio
    property real contentPreferredHeight: 160 * Style.uiScaleRatio

    anchors.fill: parent

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property bool isListening: mainInstance?.isListening ?? false

    function toggle() {
        mainInstance?.toggle()
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon: "microphone"
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                }

                NText {
                    Layout.fillWidth: true
                    text: "Whisper"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                }

                NTag {
                    text: isListening ? "Listening" : "Idle"
                    color: isListening ? Color.mPrimary : Color.mOnSurfaceVariant
                }
            }

            NButton {
                Layout.fillWidth: true
                text: isListening ? "Stop" : "Start"
                icon: isListening ? "player-stop" : "player-play"
                onClicked: toggle()
            }

            NText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                text: "Tip: bind Super+R to `qs -c noctalia-shell ipc call plugin:whisper toggle`."
            }
        }
    }
}
