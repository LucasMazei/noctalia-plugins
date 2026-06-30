import QtQuick
import QtQuick.Layouts
import qs.Widgets
import qs.Commons

ColumnLayout {
    id: root

    property var pluginApi: null

    property string valueGoalsDir: pluginApi?.pluginSettings?.goalsDir ?? ""
    property int valueYear: pluginApi?.pluginSettings?.year ?? 2026
    property int valueRefresh: pluginApi?.pluginSettings?.refreshMinutes ?? 30
    property bool valueHideBackground: pluginApi?.pluginSettings?.hideBackground ?? false

    spacing: Style.marginM

    NTextInput {
        Layout.fillWidth: true
        label: "Goals folder"
        description: "Absolute path to the folder of #goal notes. Leave empty for the default vault path."
        text: root.valueGoalsDir
        onTextChanged: root.valueGoalsDir = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Year"
        description: "Only goals whose frontmatter year matches are shown."
        inputMethodHints: Qt.ImhDigitsOnly
        text: String(root.valueYear)
        onTextChanged: { var n = parseInt(text); if (!isNaN(n)) root.valueYear = n }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        NLabel {
            label: "Refresh interval"
            description: "How often to re-scan the goal notes (minutes)."
        }
        NSlider {
            id: refreshSlider
            from: 5; to: 120; stepSize: 5
            value: root.valueRefresh
            onValueChanged: root.valueRefresh = value
        }
        Text {
            text: "Every " + refreshSlider.value + " min"
            color: Color.mOnSurfaceVariant
            font.pointSize: Style.fontSizeS
        }
    }

    NToggle {
        label: "Hide background"
        description: "Hide the panel background of the desktop widget."
        checked: root.valueHideBackground
        onToggled: function(checked) { root.valueHideBackground = checked }
    }

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.goalsDir = root.valueGoalsDir
        pluginApi.pluginSettings.year = root.valueYear
        pluginApi.pluginSettings.refreshMinutes = root.valueRefresh
        pluginApi.pluginSettings.hideBackground = root.valueHideBackground
        pluginApi.saveSettings()
        pluginApi?.mainInstance?.refresh()
    }
}
