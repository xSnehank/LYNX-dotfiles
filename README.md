# LYNX

A hand-built Arch Linux + Hyprland desktop. Waybar, rofi, swaync, kitty,
wallpaper-driven theming via matugen, and a single `lx` CLI that everything
else is bound to.

This is not a framework. There is no plugin system and no settings GUI. Every
file here is meant to be opened and read.

## Install

LYNX has to live at `~/dotfiles/lynx`: its configs name that path directly.

```bash
git clone <your LYNX repo URL> ~/dotfiles/lynx
```

See everything the installer would do, without it changing anything:

```bash
sh ~/dotfiles/lynx/install.sh --dry-run
```

Then run it for real. It asks before each step:

```bash
sh ~/dotfiles/lynx/install.sh
```

It installs the packages in `packages/repo.txt` (and asks about each one in
`packages/optional.txt`), copies the seed configs into `~/.config` where you
don't have them yet, adds an `lx` command to `~/.local/bin`, and offers to
download the wallpapers. It never overwrites a file of yours, uses sudo only
for pacman, and is safe to run again after every `git pull`.

One thing to know first: it runs `pacman -Syu --needed`, so the rest of the
system is upgraded along with the new packages. That's how Arch supports
installing packages (adding new ones onto an out-of-date system is a "partial
upgrade", which can break programs), and pacman lists everything before it
asks.

## Starting LYNX

Log in on a TTY and run:

```bash
start-hyprland
```

`start-hyprland` comes with Hyprland. If Hyprland crashes, it restarts it in
safe mode (a minimal recovery config, still locked if the screen was locked)
instead of leaving you at the TTY. Running `Hyprland` directly works too, but
shows a warning banner about the missing watchdog.

**Optional: start it automatically** when you log in on the first TTY. Add this
line to `~/.bash_profile` (or `~/.zprofile` for zsh):

```bash
[ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && exec start-hyprland
```

The trade-off: `exec` replaces your login shell, so leaving Hyprland logs you
out instead of leaving an unlocked shell behind. But if Hyprland can't start at
all, logging in on TTY 1 just logs you straight back out. Fix things from
another TTY (`Ctrl + Alt + F2`).

## The one rule that makes this maintainable

> **LYNX owns this repo and `~/.cache/lynx`. You own everything in `~/.config`.
> The two meet only through include lines.**

The installer copies small stub files into `~/.config` where you don't have
them yet, and then never touches them again. Those stubs pull in LYNX's core
config and let you override anything underneath. That means `git pull`
physically cannot clobber your customizations, because LYNX does not own a
single file in `~/.config` after install finishes.

There are no symlinks. A `git pull` takes effect immediately with no install
step in between — which is convenient, and is also the main risk (see
`docs/overrides.md`).

## Layout

| Path | Owner | Notes |
|---|---|---|
| `install.sh` | LYNX | Sets everything up. Safe to run again. |
| `config/` | LYNX | Core config. Don't edit; your changes belong in `~/.config`. |
| `templates/` | LYNX | matugen templates. The theming source of truth. |
| `seeds/` | LYNX | The stub files the installer copies into `~/.config` once. |
| `assets/` | LYNX | LYNX's own images (the default wallpaper). No third-party art. |
| `bin/lx` | LYNX | The CLI. Hyprland and the bar call it by absolute path. |
| `packages/` | LYNX | `repo.txt` is installed, `optional.txt` is asked about. |
| `tests/` | LYNX | Checks and smoke tests. They use fakes and never touch your system. |
| `~/.config/**` | **You** | Seeded once, yours forever. |
| `~/.local/bin/lx` | LYNX | A three-line script that runs `bin/lx`, so you can type `lx`. |
| `~/.cache/lynx/` | generated | Disposable. `rm -rf` it and re-run `lx theme reload`. |

## Core config contains no colors

Every core file sources or imports its palette from `~/.cache/lynx/`. Changing
wallpaper regenerates that cache and re-themes everything. Structure is
hand-written and tracked; color is generated and disposable.

## Docs

- `docs/keybinds.md` — the full keymap
- `docs/overrides.md` — how to customize without fighting updates
- `docs/theming.md` — how colors follow the wallpaper, and how that's kept from breaking anything
- `docs/known-issues.md` — what's broken upstream, why, and when it goes away
- `docs/wallpapers.md` — where the wallpapers come from, and why they aren't in this repo
- `docs/lockscreen.md` — the lock screen, compared honestly with Caelestia's
- `docs/tools.md` — screenshots, clipboard history (and what it does with passwords), power menu
- `docs/handoff.md` — where the project stands, what's been verified, and what to test first
- `tests/README.md` — how to check the repo after a change
