# Where LYNX stands

Last updated: 2026-09-18.

## Status

Everything planned is written. **None of it has run on real hardware yet.**

| Piece | What it added |
|---|---|
| 1 | Hyprland session: Lua config, monitors, input, looks, rules, keybinds, autostart |
| 2 | Waybar: core config, style, fallback palette |
| 3 | rofi: app launcher and window switcher |
| 4 | swaync: notification popups and panel |
| 5 | hyprpaper, hyprlock, hypridle: wallpaper, lock screen, idle |
| 6 | matugen theming: colors follow the wallpaper |
| 7 | Screenshots, clipboard history, power menu |
| — | `install.sh`, and `tests/` |

## What "verified" means here

`tests/` all pass: the repo checks, 108 `lx` tests, 77 installer tests under
both sh and dash. Those run against **fakes** — they prove LYNX's own logic
(what it writes, what it refuses, how it recovers), not that Hyprland, Waybar
or rofi behave on your machine the way their documentation says.

Behavior of the programs LYNX drives was checked by reading their source or
man pages for the versions Arch ships: Hyprland 0.56.2 (Lua config, and that
`hyprland.lua` wins over `hyprland.conf`), Waybar 0.15.0 (include merge, and
the workspace-click bug), rofi 2.0.0 (dmenu exit codes), swaync 0.12.6 (GTK4
CSS, state names), hyprlock/hypridle/hyprpaper, matugen 4.2.0 (flags, color
roles), cliphist and wl-clipboard (how a "secret" copy is skipped), grim,
slurp, satty, and hyprshutdown 0.1.1 (`--top-label`, `--post-cmd`).

## First run on the Arch machine

```bash
git clone <this repo> ~/dotfiles/lynx
```

```bash
sh ~/dotfiles/lynx/install.sh --dry-run
```

```bash
sh ~/dotfiles/lynx/install.sh
```

Then log in on a TTY, run `start-hyprland`, and check `hyprctl configerrors`.

## What to test, and where it's documented

| Area | Try | Read |
|---|---|---|
| Session | `SUPER + Return`, `SUPER + Q`, workspace keys, `SUPER + S` | `docs/keybinds.md` |
| Bar | Does it start at login? Scroll over workspaces (click is a known bug) | `docs/known-issues.md` |
| Launcher | `SUPER + Space`, `SUPER + Tab` | `docs/keybinds.md` |
| Notifications | `notify-send "Hello"`, `SUPER + N`, `SUPER + SHIFT + N` | `docs/overrides.md` |
| Wallpaper | `SUPER + W`, `SUPER + SHIFT + W` | `docs/wallpapers.md` |
| Lock and idle | `SUPER + ALT + L`, then wait out the idle timeouts | `docs/lockscreen.md` |
| Theming | Pick a wallpaper, watch bar/rofi/swaync/kitty/borders recolor; `SUPER + SHIFT + T` | `docs/theming.md` |
| Screenshots, clipboard, power | `Print`, `SUPER + SHIFT + V`, `SUPER + Escape` | `docs/tools.md` |

## Most likely to need fixing first

- **Waybar workspace click** does nothing under a Lua Hyprland config. Upstream
  bug, fix not released. Scroll and keybinds work. See `docs/known-issues.md`.
- **`xdg-desktop-portal-gtk`** was added to the package list on 2026-09-18
  because Hyprland's own portal preferences name gtk as the fallback and
  Hyprland's portal has no file dialog. Check that file open/save dialogs work.
- **`hyprshutdown`** options were confirmed in its source, never run. Check that
  log out, restart and shut down close apps instead of killing them.
- **Live re-theming** tells each program to reload a different way (Waybar
  SIGUSR2, `swaync-client -rs -sw`, kitty SIGUSR1, `hyprctl reload`). If one
  program keeps its old colors, that's the line to look at in `bin/lx`.
- **Lock screen crash recovery** relies on `SUPER + ALT + L` still working while
  locked, plus `misc:allow_session_lock_restore`.

## How this repo is meant to be worked on

- LYNX owns this repo and `~/.cache/lynx`. You own `~/.config`, which the
  installer seeds once and never touches again.
- `bin/lx` is the single CLI everything calls. It's a plain file — edit it
  directly.
- `git pull` takes effect immediately, with no install step. That's the
  convenience and the risk; `docs/overrides.md` covers it.
- After changing anything, run `tests/` (see `tests/README.md`).
