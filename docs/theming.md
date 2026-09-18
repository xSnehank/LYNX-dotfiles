# Theming

Colors follow your wallpaper. Pick a new one and, a moment later, window
borders, the bar, the launcher, notifications, the lock screen and kitty all
switch to a matching palette.

## What changes, and when

| Program | Palette file (`~/.cache/lynx/`) | Picks up new colors |
|---|---|---|
| Hyprland window borders | `colors.lua` | Immediately (`hyprctl reload`) |
| Waybar | `colors.css` | Immediately (SIGUSR2 reload, no restart) |
| swaync | `colors-gtk4.css` | Immediately (`swaync-client -rs`) |
| kitty | `colors-kitty.conf` | Immediately, in every open window (SIGUSR1) |
| rofi | `colors.rasi` | Next time it opens |
| Lock screen | `colors-hyprlock.conf` | Next time it locks |

**Not themed:** other GTK and Qt applications (file managers, Firefox, and so
on). LYNX doesn't write into their config folders, because those are yours. To
theme them, see "Your own templates" below.

## How it works

```
new wallpaper
   │
   ▼
matugen  ──renders──▶  ~/.cache/lynx/theme/staging/   (6 files)
                              │
                              ▼
                  lx checks every file:
                  all 9 roles present, values the right shape
                     │                         │
                  all good                  anything wrong
                     │                         │
                     ▼                         ▼
      moved into ~/.cache/lynx          nothing changes;
      (each move is atomic),            you get a notification,
      running programs reload           and the log says why
```

Why the extra steps:

- **matugen writes files in place, not atomically.** Rendering straight into
  `~/.cache/lynx` would let Waybar or the lock screen catch a half-written
  file. Staging plus atomic moves means they never can.
- **A bad render can't break anything.** If a template fails or produces an
  incomplete file, the previous palette stays exactly as it was.
- **matugen never stops to ask a question.** When an image has several
  candidate colors and nothing says which to pick, matugen asks
  interactively. From a keybind, nobody can answer. LYNX always passes
  `--source-color-index 0`, the most dominant color, and gives matugen no
  terminal to ask on.
- **One run at a time.** Flick through five wallpapers quickly, and the
  colors end up matching the last one, without five runs piling up.

Everything runs in the background: changing wallpaper never waits for it.

## Commands

| Command | What it does |
|---|---|
| `SUPER + SHIFT + T` | Switch between dark and light (`lx theme mode toggle`) |
| `lx theme reload` | Regenerate from the current wallpaper |
| `lx theme mode dark` / `light` | Choose explicitly; remembered |
| `lx theme scheme NAME` | How colors are derived; remembered (see below) |
| `lx theme status` | Mode, scheme, which wallpaper the colors came from, last problem |
| `lx theme reset` | Back to LYNX's fixed fallback palette (Catppuccin Mocha) |

Schemes, all from matugen:

| Scheme | Character |
|---|---|
| `tonal-spot` | The default. Calm, one accent from the wallpaper. |
| `vibrant` | More saturated accents. |
| `expressive` | Accents deliberately shifted away from the wallpaper's hues. |
| `neutral` | Near-grey, only a hint of color. |
| `monochrome` | Grey only. |
| `fidelity`, `content` | Stay as close to the wallpaper's own colors as possible. |
| `rainbow`, `fruit-salad` | Playful, multi-hue. |

Mode and scheme are stored in `~/.cache/lynx/theme/`. Clearing the cache resets
them to dark + tonal-spot.

## Turning it off

In `~/.config/hypr/hyprland.lua`, before `require("hypr.core")`:

```lua
s.theme = false
```

Then run `lx theme reset` once to put the fixed palette back everywhere.
With theming off, changing wallpaper no longer recolors anything.

## The palette contract

Every program's palette uses the same 9 Material You roles, spelled the way
that program's config format requires:

| Role | Used for |
|---|---|
| `surface` | Main backgrounds |
| `surface_container` | Cards, pills, input fields |
| `on_surface` | Normal text |
| `on_surface_variant` | Dimmed text |
| `outline` | Borders |
| `primary` | The accent: active workspace, selection, focus |
| `on_primary` | Text on top of the accent |
| `tertiary` | Warnings, Caps Lock |
| `error` | Errors, critical notifications |

The fallback palettes (`config/*/fallback-colors.*`), the templates
(`templates/`) and `lx`'s checks all use this list. The repo check verifies the
fallbacks are identical and the templates cover every role.

kitty also gets 16 terminal colors, from matugen's base16 palette.

## Your own templates

Want matugen colors in something LYNX doesn't theme? Write a normal matugen
config at `~/.config/matugen/config.toml`, with your own templates and output
paths. Whenever LYNX generates a theme, it runs your config with the same
wallpaper, mode and scheme. Your outputs aren't staged or checked by LYNX; if
your config fails, you get a notification and `~/.cache/lynx/theme/matugen-user.log`.

## When something looks wrong

1. `lx theme status` shows the last problem, if there was one.
2. `~/.cache/lynx/theme/matugen.log` is matugen's own output.
3. A file that failed the check is left in `~/.cache/lynx/theme/staging/`.
4. `lx theme reset` always gets you back to a known-good palette.
