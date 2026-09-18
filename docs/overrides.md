# Customizing LYNX without fighting updates

## The model

LYNX owns `~/dotfiles/lynx` and `~/.cache/lynx`. You own everything in
`~/.config`. The installer writes your `~/.config` files **once** and never
touches them again, so `git pull` can't clobber your work: LYNX doesn't own a
single file there.

There are no symlinks. A `git pull` takes effect immediately.

## Hyprland: three moves

All of this happens in `~/.config/hypr/hyprland.lua`.

**1. Change a setting.** Do this before `require("hypr.core")`:

```lua
local s = require("hypr.settings")
s.gaps_in = 2
s.blur    = false
s.bar     = false   -- no Waybar
local lynx = require("hypr.core")
```

Order matters. Core reads these values while it loads, so setting them afterwards
is too late. Every setting is listed in `config/hypr/settings.lua`.

**2. Add something.** Call `hl.*` anywhere after core:

```lua
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
hl.window_rule({ name = "float-pavu", match = { class = "pavucontrol" }, float = true })
```

**3. Turn one of ours off.** Every LYNX bind and rule returns a handle:

```lua
lynx.binds.terminal:set_enabled(false)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))
```

Handle names are the table keys in `config/hypr/keybinds.lua` and `rules.lua`.
If a LYNX bind ever fails to register, its handle is `nil`, and calling a method
on `nil` is an error that stops the rest of *your* file. If you want to be
defensive:

```lua
if lynx.binds.terminal then lynx.binds.terminal:set_enabled(false) end
```

On `hyprctl reload`, Hyprland starts a fresh Lua state and re-runs every module
from scratch, so no stale values carry over between reloads.

## Waybar: two files

Both live in `~/.config/waybar/`, and both are yours.

**`config.jsonc`** includes LYNX's core bar config. Waybar merges the two like
this (checked in Waybar 0.15.0's `src/config.cpp`):

| You write | Result |
|---|---|
| A value, e.g. `"position": "bottom"` | Yours wins |
| Part of a module, e.g. `"clock": { "format": "{:%H:%M}" }` | Only that key changes; LYNX's other clock settings stay |
| An array, e.g. `"modules-right": [ … ]` | Replaces LYNX's array entirely, so list every module you want |

**`style.css`** imports the palette, then LYNX's stylesheet. Rules you add after
the imports win at equal specificity. Use palette names (`@primary`, `@surface`,
…) instead of hex so your tweaks follow the wallpaper once theming lands. The
full list is in `config/waybar/fallback-colors.css`.

Apply changes with:

```bash
sh ~/dotfiles/lynx/bin/lx bar restart
```

## Rofi: one file

`~/.config/rofi/config.rasi` imports LYNX's rofi config. Anything you write
after the import wins, because rasi keeps the last value it parses. Options
go in `configuration { }`, looks go in widget sections:

```css
configuration { icon-theme: "Adwaita"; }
listview      { lines: 12; }
```

Palette names use hyphens in rasi (`@on-surface`), not underscores: rofi
doesn't allow underscores in names. There's nothing to restart, because rofi
reads its config fresh every time it opens.

## swaync: the exception

**`style.css`** works like Waybar's: it imports the palette and LYNX's
stylesheet, and your rules come after. swaync is GTK4, so palette colors
are CSS variables here: `var(--primary)`, `var(--on_surface)`.

**`config.json` is entirely yours.** It's the one LYNX config that doesn't
pull in a core file, for two reasons:

- swaync has no way to include another config file.
- swaync usually isn't started by LYNX. systemd and D-Bus start it on
  demand, and those always read `~/.config/swaync/config.json`. A generated
  or merged file would be ignored exactly when it matters.

So LYNX seeds a commented config once, and from then on it's yours. To see
what a newer LYNX changed in its version:

```bash
diff ~/.config/swaync/config.json ~/dotfiles/lynx/seeds/swaync/config.json
```

Apply changes to either file with `sh ~/dotfiles/lynx/bin/lx notify reload`.

**Turning it off.** `s.notifications = false` stops LYNX starting swaync and
removes its keybinds. swaync can still start by itself when an app sends a
notification, or when the bar's bell asks for the count, because that's how
D-Bus activation works. To stop it completely:
`systemctl --user mask swaync`.

## Lock screen, idle, wallpaper

- **`~/.config/hypr/hyprlock.conf`** sources LYNX's lock screen in sections.
  Your settings go *between* the defaults and the layout, because hyprlock
  swaps variables in as it reads. Remove a panel by commenting out its line.
  Details: `lockscreen.md`.
- **`~/.config/hypr/hypridle.conf`** sources LYNX's lock/sleep wiring; the
  timeouts below it are yours. Apply with `systemctl --user restart hypridle`.
- **`~/.config/hypr/hyprpaper.conf`** sources LYNX's config. Which wallpaper
  shows isn't config at all: use `lx wallpaper` (`SUPER + W`).

## Theme and kitty

- Colors follow your wallpaper. `lx theme mode` and `lx theme scheme` change
  how; `s.theme = false` followed by `lx theme reset` turns it off. Details:
  `theming.md`.
- **`~/.config/kitty/kitty.conf`** includes the generated colors. Anything
  after that line overrides them.
- **Your own matugen templates:** write a config at
  `~/.config/matugen/config.toml`. LYNX runs it with the same colors every
  time it generates a theme.

## Screenshots, clipboard, power

- **Screenshot folder:** `hl.env("LYNX_SCREENSHOT_DIR", ...)` in your `hyprland.lua`.
- **`SUPER + V` for clipboard history** instead of floating: `tools.md` has the
  four lines.
- **Passwords and clipboard history:** read the section in `tools.md` before
  relying on it.

## The risk this design accepts

With no install step between `git pull` and taking effect, a pull that ships a
broken core file breaks you *immediately*. Two mitigations:

- Once you're happy, check out a tag instead of tracking `main`.
- Run `hyprctl configerrors` after any pull.

It's a deliberate trade: instant iteration while building, with no safety
buffer on updates.

## When something breaks

**The bar is gone or looks wrong.**

```bash
sh ~/dotfiles/lynx/bin/lx bar restart
```

If it won't stay up, the reason is in `~/.cache/lynx/waybar.log`.

**The launcher opens an error box instead of a list.** That's rofi reporting
a syntax error in a `.rasi` file, and the message names the file. Softer
problems, like a file it couldn't import, are warnings and go to
`~/.cache/lynx/rofi.log`.

**Notifications don't appear.** Send a test with `notify-send "Hello"`, then
check the service with `systemctl --user status swaync` and its log with
`journalctl --user -u swaync -b`.

**The lock screen crashed.** The session stays locked. Press
`SUPER + ALT + L` to start a new lock screen, or see `lockscreen.md` for
the TTY route.

**Hyprland reports config errors.** Run `hyprctl configerrors`, fix what it
names, then `hyprctl reload`. Hyprland checks syntax before it clears the old
config, so a syntax error on reload keeps your working binds.

**Hyprland can't load your config at startup.** It falls back to a small
built-in emergency config (`src/config/lua/Emergency.hpp`): `SUPER + Q` opens a
terminal and `SUPER + M` exits. Careful: `SUPER + Q` means *close window* in
LYNX. From that terminal, run `hyprctl configerrors`.

**No usable session at all.** From a TTY (`Ctrl + Alt + F2`), swap in
Hyprland's own shipped example config, which is known-good:

```bash
mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.broken && cp /usr/share/hypr/hyprland.lua ~/.config/hypr/hyprland.lua
```

That gets you a plain Hyprland session. Then diff your broken file against the
seed in `seeds/hypr/hyprland.lua`.
