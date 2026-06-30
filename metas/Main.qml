import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    readonly property string home: Quickshell.env("HOME") || "/home/Usuario"

    // ---- Settings (with sane defaults) ----
    readonly property string goalsDir: (pluginApi?.pluginSettings?.goalsDir && pluginApi.pluginSettings.goalsDir.length > 0)
        ? pluginApi.pluginSettings.goalsDir
        : (home + "/Insync/mazei.lucas@gmail.com/Google Drive/Obsidian/Study/6. Projects/The Biggest Project (me)/Yearly Planning/2026/Goals")
    readonly property int year: pluginApi?.pluginSettings?.year ?? 2026
    readonly property int refreshMinutes: pluginApi?.pluginSettings?.refreshMinutes ?? 30
    readonly property bool hideBackground: pluginApi?.pluginSettings?.hideBackground ?? false

    readonly property string scriptPath: home + "/.config/noctalia/plugins/metas/goals-scan.py"
    // Quickshell may be launched (by Hypr) with a minimal PATH, so pin python3.
    readonly property string pythonCmd: "/usr/bin/python3"

    // ---- Public state (read by the desktop widget) ----
    property real overall: 0
    property int totalGoals: 0
    property int onTarget: 0
    property var categories: []
    property var goals: []
    property bool loaded: false
    property string error: ""

    signal goalsUpdated()

    onPluginApiChanged: if (pluginApi) refresh()
    Component.onCompleted: refresh()

    function refresh() {
        if (scanProcess.running) return
        scanProcess.command = [pythonCmd, scriptPath, goalsDir, String(year)]
        scanProcess.running = true
    }

    Process {
        id: scanProcess
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.overall = d.overall ?? 0
                    root.totalGoals = d.totalGoals ?? 0
                    root.onTarget = d.onTarget ?? 0
                    root.categories = d.categories ?? []
                    root.goals = d.goals ?? []
                    root.error = ""
                    root.loaded = true
                    root.goalsUpdated()
                } catch (e) {
                    root.error = "parse error"
                    Logger.e("Metas", "Failed to parse scan output: " + e)
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    root.error = text.trim()
                    Logger.w("Metas", "scan stderr: " + text.trim())
                }
            }
        }
    }

    // Periodic refresh (goals change rarely; the vault file is the source of truth)
    Timer {
        interval: Math.max(1, root.refreshMinutes) * 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Manual refresh over IPC: `noctalia-shell ipc call plugin:metas refresh`
    IpcHandler {
        target: "plugin:metas"
        function refresh() { root.refresh() }
    }
}
