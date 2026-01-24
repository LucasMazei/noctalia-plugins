## Whisper (Noctalia plugin)

Voice toggle overlay + `hyprvoice toggle` integration for Noctalia Shell.

- **Plugin IPC**: `plugin:whisper toggle`
- **Upstream hyprvoice**: `https://github.com/leonardotrapani/hyprvoice`

## Install hyprvoice

This plugin expects a `hyprvoice` binary in your `PATH` that supports:

- `hyprvoice toggle`

### Start hyprvoice on login (required)

`hyprvoice toggle` usually needs the background daemon running. If you’re on Hyprland, add this to your startup config:

```conf
exec-once = bash -c "/home/your_user/.local/bin/hyprvoice serve" > /tmp/hypervoice.log 2>&1
```

Install it from the upstream repo and verify:

```bash
command -v hyprvoice
hyprvoice --help
```

If your `hyprvoice` is not on `PATH`, you can set the command in plugin settings (see **Settings**).

## Install the plugin

Noctalia loads plugins from `~/.config/noctalia/plugins/` (symlinks are fine).

```bash
ln -s /path/to/noctalia-plugins/whisper ~/.config/noctalia/plugins/whisper
systemctl --user restart noctalia
```

Then enable it in **Noctalia Settings → Plugins → Whisper**.

## Hyprland keybind

In your `hyprland.conf` / user keybinds:

```conf
bind = $mainMod, R, exec, qs -c noctalia-shell ipc call plugin:whisper toggle
```

## Settings

- **hyprvoiceCommand**: command used to run hyprvoice (default: `hyprvoice`).
  - Example: set to `/home/you/.local/bin/hyprvoice` if needed.

## Debug

List all IPC targets:

```bash
qs -c noctalia-shell ipc call show
```

Inspect Whisper handlers:

```bash
qs -c noctalia-shell ipc call plugin:whisper show
```
