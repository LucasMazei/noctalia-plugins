import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Modules.DesktopWidgets

DraggableDesktopWidget {
    id: root

    property var pluginApi: null
    readonly property var core: pluginApi?.mainInstance

    readonly property real overall: core?.overall ?? 0
    readonly property int totalGoals: core?.totalGoals ?? 0
    readonly property int onTarget: core?.onTarget ?? 0
    readonly property var categories: core?.categories ?? []
    readonly property var goals: core?.goals ?? []
    readonly property int year: core?.year ?? 2026

    showBackground: !(core?.hideBackground ?? false)

    readonly property real pad: 14
    implicitWidth: 280
    implicitHeight: contentCol.implicitHeight + pad * 2

    function pct(r) { return Math.round((r || 0) * 100) + "%" }
    function barColor(r) { return (r || 0) >= 0.999 ? Color.mTertiary : Color.mPrimary }

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: Style.marginS

        // ---- Header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NIcon {
                icon: "target"
                color: Color.mPrimary
                pointSize: Style.fontSizeL
            }
            NText {
                text: "Metas " + root.year
                font.pixelSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.fillWidth: true
            }
            NText {
                text: root.pct(root.overall)
                font.pixelSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mPrimary
            }
        }

        // ---- Goal dots (one per goal, filled when on target) ----
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 5
            Repeater {
                model: root.goals
                delegate: Rectangle {
                    width: 9; height: 9; radius: 4.5
                    color: (modelData.ratio || 0) >= 0.999 ? Color.mTertiary : "transparent"
                    border.width: (modelData.ratio || 0) >= 0.999 ? 0 : 1.5
                    border.color: Color.mOutline
                }
            }
        }

        NDivider { Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2 }

        // ---- Category rows ----
        Repeater {
            model: root.categories
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: modelData.type
                    font.pixelSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.preferredWidth: 86
                    elide: Text.ElideRight
                }

                // mini progress bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Color.mSurfaceVariant

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: Math.max(0, Math.min(1, modelData.ratio || 0)) * parent.width
                        color: root.barColor(modelData.ratio)
                        Behavior on width { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
                    }
                }

                NText {
                    text: root.pct(modelData.ratio)
                    font.pixelSize: Style.fontSizeS
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 36
                }
            }
        }

        // ---- Footer ----
        NText {
            Layout.fillWidth: true
            Layout.topMargin: 2
            horizontalAlignment: Text.AlignHCenter
            text: root.onTarget + " / " + root.totalGoals + " no alvo"
            font.pixelSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
        }
    }
}
