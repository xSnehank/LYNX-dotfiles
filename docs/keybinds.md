# LYNX keybinds

`SUPER` is the modifier (change it with `s.mod`). Everything here is defined in
`config/hypr/keybinds.lua`, and you can switch any bind off individually — see
`overrides.md`.

## Applications

| Keys | Action |
|---|---|
| `SUPER + Return` | Terminal |

## Windows

| Keys | Action |
|---|---|
| `SUPER + Q` | Close window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + SHIFT + F` | Toggle maximize (bar stays visible) |
| `SUPER + V` | Toggle floating |
| `SUPER + P` | Toggle pseudotile |
| `SUPER + T` | Toggle split direction (dwindle) |
| `SUPER + LMB` drag | Move window |
| `SUPER + RMB` drag | Resize window |
| `SUPER + SHIFT + E` | **Exit Hyprland immediately, no confirmation** |

## Focus, move, resize

The same four directions throughout: arrow keys, or vim keys `H J K L`.

| Keys | Action |
|---|---|
| `SUPER + ←↑↓→` / `H J K L` | Move focus |
| `SUPER + SHIFT + ←↑↓→` / `H J K L` | Move window |
| `SUPER + CTRL + ←↑↓→` / `H J K L` | Resize window by 40px (hold to repeat) |

## Workspaces

| Keys | Action |
|---|---|
| `SUPER + 1…9, 0` | Switch to workspace 1–10 |
| `SUPER + SHIFT + 1…9, 0` | Move window to workspace 1–10 |
| `SUPER + scroll` | Cycle through workspaces |
| `SUPER + S` | Toggle scratchpad |
| `SUPER + SHIFT + S` | Move window to scratchpad |

## Bar

Only bound when `s.bar = true` (the default).

| Keys | Action |
|---|---|
| `SUPER + B` | Hide / show the bar |
| `SUPER + SHIFT + B` | Restart the bar (after editing its config) |

Mouse actions on the bar itself:

| Where | Action |
|---|---|
| Workspaces | Scroll to switch. **Clicking doesn't work yet** — see `known-issues.md` |
| Clock | Click to toggle the date; hover for a calendar |
| Volume | Scroll to change; click to mute |
| Bell | Click for the notification panel; right-click for Do Not Disturb |
| Power | Click for the power menu; right-click to lock |

## Launcher

Only bound when `s.launcher = true` (the default). Press the same keys again
to close.

| Keys | Action |
|---|---|
| `SUPER + Space` | App launcher: type to filter, Enter to open |
| `SUPER + Tab` | Window switcher |

## Notifications

Only bound when `s.notifications = true` (the default).

| Keys | Action |
|---|---|
| `SUPER + N` | Open / close the notification panel |
| `SUPER + SHIFT + N` | Toggle Do Not Disturb |

Inside the panel (swaync's own shortcuts): arrow keys to move, `Delete` to
dismiss, `Shift + C` to clear all, `Shift + D` for Do Not Disturb, `Escape`
to close.

## Wallpaper

Only bound when `s.wallpaper = true` (the default). See `wallpapers.md`.

| Keys | Action |
|---|---|
| `SUPER + W` | Wallpaper picker with thumbnails |
| `SUPER + SHIFT + W` | Random wallpaper |

## Lock

Only bound when `s.lock = true` (the default). See `lockscreen.md`.

| Keys | Action |
|---|---|
| `SUPER + ALT + L` | Lock now. Also works while locked: restarts a crashed lock screen |

## Theme

Only bound when `s.theme = true` (the default). See `theming.md`.

| Keys | Action |
|---|---|
| `SUPER + SHIFT + T` | Switch between dark and light colors |

## Screenshots

Only bound when `s.screenshots = true` (the default). See `tools.md`.

| Keys | Action |
|---|---|
| `Print` | Region: drag a rectangle, saved and copied |
| `SUPER + SHIFT + P` | Region, for keyboards without Print |
| `SHIFT + Print` | The monitor you're on |
| `CTRL + Print` | The focused window |

## Clipboard and power

| Keys | Action |
|---|---|
| `SUPER + SHIFT + V` | Clipboard history (`Alt + D` deletes an entry) |
| `SUPER + Escape` | Power menu: lock, suspend, log out, restart, shut down |

## Hardware keys

| Keys | Action |
|---|---|
| Volume up / down / mute | PipeWire via `wpctl` |
| Mic mute | `wpctl` |
| Brightness up / down | `brightnessctl` |

These keep working while the screen is locked (`locked = true`).
