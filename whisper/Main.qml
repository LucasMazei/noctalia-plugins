import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    // Injected by Noctalia when loaded as a plugin
    property var pluginApi: null

    property bool isListening: false

    readonly property string hyprvoiceCommand: (pluginApi?.pluginSettings?.hyprvoiceCommand ?? "/home/Usuario/.local/bin/hyprvoice")

    function toggle() {
        root.isListening = !root.isListening
        Logger.i("Whisper", "toggle(): isListening=" + root.isListening)
        hyprvoiceProcess.startDetached()
    }

    // Overlay indicator (our actual UI)
    VoiceOverlay {
        id: overlay
        isListening: root.isListening
    }

    // Runs `hyprvoice toggle` (detached) whenever we toggle
    Process {
        id: hyprvoiceProcess
        command: [root.hyprvoiceCommand, "toggle"]
    }

    // Noctalia-style IPC entrypoint (this is what shows up in `ipc call show`)
    IpcHandler {
        target: "plugin:whisper"

        function toggle() {
            root.toggle()
        }
    }
}

