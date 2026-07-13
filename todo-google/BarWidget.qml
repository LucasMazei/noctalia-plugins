import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  implicitWidth: barIsVertical ? Style.capsuleHeight : contentRow.implicitWidth + Style.marginM * 2
  implicitHeight: Style.capsuleHeight

  function getIntValue(value, defaultValue) {
    return (typeof value === 'number') ? Math.floor(value) : defaultValue;
  }

  readonly property int todoCount: getIntValue(pluginApi?.pluginSettings?.count, getIntValue(pluginApi?.manifest?.metadata?.defaultSettings?.count, 0))
  readonly property int completedCount: getIntValue(pluginApi?.pluginSettings?.completedCount, getIntValue(pluginApi?.manifest?.metadata?.defaultSettings?.completedCount, 0))
  readonly property int activeCount: todoCount - completedCount

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  readonly property bool isConnected: pluginApi?.pluginSettings?.googleAccessToken ? true : false
  readonly property string syncStatus: pluginApi?.pluginSettings?.syncStatus || "disconnected"

  color: Style.capsuleColor
  radius: Style.radiusL

  Connections {
    target: Color
    function onMOnHoverChanged() { }
    function onMOnSurfaceChanged() { }
  }

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: Style.marginS

    NIcon {
      icon: "checklist"
      applyUiScale: false
      color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
    }

    NText {
      visible: !barIsVertical
      text: {
        var count = activeCount;
        var text = count + " todo" + (count !== 1 ? 's' : '');
        return text;
      }
      color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
      pointSize: Style.barFontSize
      font.weight: Font.Medium
    }

    // Google Tasks sync status indicator (small icon)
    NIcon {
      visible: isConnected && !barIsVertical
      icon: {
        if (syncStatus === "synced") return "cloud-done";
        if (syncStatus === "syncing") return "cloud-sync";
        if (syncStatus === "error") return "cloud-off";
        return "cloud-off";
      }
      applyUiScale: false
      color: {
        if (syncStatus === "synced") return Color.mPrimary;
        if (syncStatus === "syncing") return Color.mTertiary;
        if (syncStatus === "error") return Color.mError;
        return Color.mOnSurfaceVariant;
      }
      pointSize: Style.barFontSize * 0.8
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      root.color = Color.mHover;
    }

    onExited: {
      root.color = Style.capsuleColor;
    }

    onClicked: {
      if (pluginApi) {
        Logger.i("TodoGoogle", "Opening Todo panel");
        pluginApi.openPanel(root.screen);
      }
    }
  }
}
