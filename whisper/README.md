## Noctalia plugin wiring

This plugin exposes a Noctalia IPC endpoint:

- `plugin:whisper toggle`

### Hyprland keybind example

In your `hyprland.conf` / user keybinds:

```
bind = $mainMod, R, exec, qs -c noctalia-shell ipc call plugin:whisper toggle
```

### Debug

List all IPC targets:

```
qs -c noctalia-shell ipc call show
```

Inspect Whisper handlers:

```
qs -c noctalia-shell ipc call plugin:whisper show
```
