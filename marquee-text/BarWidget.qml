import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property bool fortuneEnabled: cfg.fortuneEnabled ?? defaults.fortuneEnabled ?? false
    readonly property bool listEnabled: cfg.listEnabled ?? defaults.listEnabled ?? false
    readonly property int maxWidth: cfg.maxWidth ?? defaults.maxWidth ?? 280
    readonly property int rollingSpeed: cfg.rollingSpeed ?? defaults.rollingSpeed ?? 25
    property string displayText: fortuneEnabled
        ? (pluginApi?.mainInstance?.fortuneText ?? "")
        : listEnabled
            ? (pluginApi?.mainInstance?.listText ?? "")
            : (cfg.text ?? defaults.text ?? "")

    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    readonly property real fullTextWidth: hiddenLabel.implicitWidth + Style.marginL * 2
    readonly property real cappedWidth: Math.min(fullTextWidth, maxWidth)
    readonly property real contentWidth: isVertical ? capsuleHeight : cappedWidth
    readonly property real contentHeight: capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    // Hidden label used to measure full text width
    Text {
        id: hiddenLabel
        visible: false
        text: root.displayText
        font.pointSize: Style.barFontSize
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        // Vertical bar: just show truncated text
        Text {
            visible: root.isVertical
            anchors.centerIn: parent
            text: root.displayText
            color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            font.pointSize: Style.barFontSize
            elide: Text.ElideRight
            width: parent.width - Style.marginS * 2
            horizontalAlignment: Text.AlignHCenter
        }

        // Horizontal bar: marquee scroll
        Item {
            visible: !root.isVertical
            anchors.fill: parent
            anchors.leftMargin: Style.marginS
            anchors.rightMargin: Style.marginS
            clip: true

            Text {
                id: scrollLabel
                y: (parent.height - height) / 2
                text: root.displayText
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                font.pointSize: Style.barFontSize

                readonly property bool overflows: contentWidth > parent.width
                x: scrollAnim.running ? 0 : (overflows ? 0 : (parent.width - contentWidth) / 2)

                SequentialAnimation {
                    id: scrollAnim
                    running: scrollLabel.overflows
                    loops: Animation.Infinite

                    PauseAnimation { duration: 2000 }
                    NumberAnimation {
                        target: scrollLabel
                        property: "x"
                        from: 0
                        to: -(scrollLabel.contentWidth - scrollLabel.parent.width + 20)
                        duration: scrollLabel.contentWidth * root.rollingSpeed
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: scrollLabel
                        property: "x"
                        to: 0
                        duration: 500
                    }
                }
            }
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" },
            { "label": pluginApi?.tr("menu.next") ?? "Next", "action": "next", "icon": "skip_next" }
        ]
        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (action === "next" && pluginApi?.mainInstance) {
                if (root.fortuneEnabled && pluginApi.mainInstance.triggerFortune) pluginApi.mainInstance.triggerFortune();
                else if (root.listEnabled && pluginApi.mainInstance.pickFromFile) pluginApi.mainInstance.pickFromFile();
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi?.mainInstance) {
                    if (root.fortuneEnabled && pluginApi.mainInstance.triggerFortune) pluginApi.mainInstance.triggerFortune();
                    else if (root.listEnabled && pluginApi.mainInstance.pickFromFile) pluginApi.mainInstance.pickFromFile();
                    else BarService.openPluginSettings(screen, pluginApi.manifest);
                }
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen);
            }
        }
    }
}
