# Known issues

Each entry covers what's broken, why (with the evidence), what LYNX does about
it, and when it goes away.

## Clicking a workspace in Waybar does nothing

**Affects:** Waybar 0.15.0 (what Arch ships) with a Lua Hyprland config,
which is what LYNX uses. Hyprland 0.55 and later.

**Still works:** `SUPER + 1…0`, and scrolling over the workspace module.

**Why.** With a Lua config, Hyprland evaluates `hyprctl dispatch X` as Lua,
as `return hl.dispatch(X)` (`src/debug/HyprCtl.cpp` in Hyprland v0.56.2).
Waybar 0.15.0 still sends the old string form on click, `dispatch workspace 2`,
which turns into `hl.dispatch(workspace 2)`: a Lua syntax error. That string
is hardcoded in Waybar's C++ (`handleClicked` in
`src/modules/hyprland/workspace.cpp`), so no config option can change it.

**What LYNX does.** Scroll switching is set explicitly in the bar config using
the Lua dispatch syntax. That goes through Waybar's generic scroll handler, not
the broken click code.

**When it goes away.** Waybar fixed this upstream in
[PR #5231](https://github.com/Alexays/Waybar/pull/5231), merged 2026-08-27.
Waybar now reads `configProvider` from Hyprland's `systeminfo` and sends Lua
dispatches when that's `lua`. As of 2026-09-13 the fix isn't in a tagged
release, and Arch's `waybar 0.15.0-3` doesn't patch it in. Once Arch ships the
next release, clicks start working **with no change to LYNX**.

**If you want clicks now:** `waybar-git` in the AUR builds Waybar's
development branch, which has the fix.

> **Stability trade:** `waybar-git` means running whatever landed on Waybar's
> `master` the day you built it. That is the opposite of LYNX's priority #1.
> If you try it and an update breaks the bar, go back with
> `sudo pacman -S waybar`.

## Live CSS reload is off by default

Waybar's `reload_style_on_change` re-reads the stylesheet whenever the file
changes. It's convenient while you're styling.

In 0.15.0 that reload path has no error handling of its own:
`src/util/css_reload_helper.cpp` calls straight into `setupCss`, which throws
when a stylesheet fails to load. Save a stylesheet with a mistake in it and the
bar is left broken until it's restarted. (What's verified is the missing error
handling. Whether you end up with an unstyled bar or no bar hasn't been tested.)

The bigger reason it's off: once theming lands, the palette file gets rewritten
every time the wallpaper changes, and a reload that catches that file half-written
would hit exactly this path.

Turn it on in `~/.config/waybar/config.jsonc` if you want it. If the bar ever
disappears, `sh ~/dotfiles/lynx/bin/lx bar restart` brings it back.
