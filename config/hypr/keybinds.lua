-- LYNX :: keybinds
-- https://wiki.hypr.land/Configuring/Basics/Binds/
--
-- Every dispatcher and bind option in this file was checked against Hyprland
-- v0.56.2's own source (src/config/lua/bindings/), not copied from docs or
-- other people's dotfiles. If a future Hyprland renames one, that single bind
-- shows up in `hyprctl configerrors` and everything else still loads: Hyprland
-- reports a bad bind rather than aborting the config.
--
-- How Hyprland's parser actually reads a key string:
--   - modifiers come first, joined with " + "     "SUPER + SHIFT + Q"
--   - modifier names are exact and UPPERCASE      SUPER  SHIFT  CTRL  ALT
--   - the Enter key is "Return"
--
-- Every bind returns a handle, and the names below are stable. To replace one
-- of ours instead of forking this file:
--     local lynx = require("hypr.core")
--     lynx.binds.terminal:set_enabled(false)
--     hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))

local s   = require("hypr.settings")
local mod = s.mod
local B   = {}

-- Runs LYNX's CLI: `sh` plus an absolute path, so this depends on neither
-- PATH nor the executable bit. See s.lynx_dir in settings.lua.
local function lx(args)
    return hl.dsp.exec_cmd("sh '" .. s.lynx_dir .. "/bin/lx' " .. args)
end

-- ─── Applications ──────────────────────────────────────────────────────────
B.terminal = hl.bind(mod .. " + Return", hl.dsp.exec_cmd(s.terminal))

-- ─── Windows ───────────────────────────────────────────────────────────────
B.close        = hl.bind(mod .. " + Q",         hl.dsp.window.close())
B.fullscreen   = hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
B.maximize     = hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
B.toggle_float = hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
B.pseudo       = hl.bind(mod .. " + P",         hl.dsp.window.pseudo())
B.toggle_split = hl.bind(mod .. " + T",         hl.dsp.layout("togglesplit"))  -- dwindle only

-- Exit Hyprland. A three-key chord on purpose: this ends your session
-- instantly, with no confirmation.
B.exit = hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

-- ─── Focus ─────────────────────────────────────────────────────────────────
-- Every direction works with both arrows and vim keys. Arrows are easy to
-- discover; hjkl is faster once it's muscle memory. Having both costs nothing.
B.focus_left  = hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
B.focus_right = hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
B.focus_up    = hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
B.focus_down  = hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

B.focus_h = hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
B.focus_l = hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
B.focus_k = hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
B.focus_j = hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))

-- ─── Move windows (SHIFT) ──────────────────────────────────────────────────
B.move_left  = hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
B.move_right = hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
B.move_up    = hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
B.move_down  = hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

B.move_h = hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
B.move_l = hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
B.move_k = hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
B.move_j = hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- ─── Resize windows (CTRL) ─────────────────────────────────────────────────
-- 40px per press; hold the keys to keep resizing. x/y are pixel deltas
-- applied to the focused window's size (relative = true), so left/up shrink
-- and right/down grow.
local step = 40
local hold = { repeating = true }

B.resize_left  = hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), hold)
B.resize_right = hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x =  step, y = 0,     relative = true }), hold)
B.resize_up    = hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), hold)
B.resize_down  = hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,     y =  step, relative = true }), hold)

B.resize_h = hl.bind(mod .. " + CTRL + H", hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), hold)
B.resize_l = hl.bind(mod .. " + CTRL + L", hl.dsp.window.resize({ x =  step, y = 0,     relative = true }), hold)
B.resize_k = hl.bind(mod .. " + CTRL + K", hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), hold)
B.resize_j = hl.bind(mod .. " + CTRL + J", hl.dsp.window.resize({ x = 0,     y =  step, relative = true }), hold)

-- ─── Workspaces ────────────────────────────────────────────────────────────
-- 20 near-identical binds as one readable loop.
B.workspace = {}
B.move_to   = {}
for i = 1, 10 do
    local key = i % 10                      -- workspace 10 sits on the 0 key
    B.workspace[i] = hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    B.move_to[i]   = hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad: a hidden workspace you summon over whatever you're doing.
B.special_toggle = hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
B.special_move   = hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces that exist ("e" = existing).
B.workspace_next = hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
B.workspace_prev = hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ─── Mouse ─────────────────────────────────────────────────────────────────
-- 272 = left button, 273 = right button. The "mouse:" key name is what makes
-- these mouse binds. Hyprland 0.56.2's bind parser doesn't actually read the
-- `mouse = true` option; it's kept because Hyprland's own shipped example
-- config (/usr/share/hypr/hyprland.lua) writes it, and it's harmless.
B.drag   = hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
B.resize = hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ─── Bar ───────────────────────────────────────────────────────────────────
if s.bar then
    B.bar_toggle  = hl.bind(mod .. " + B",         lx("bar toggle"))
    B.bar_restart = hl.bind(mod .. " + SHIFT + B", lx("bar restart"))
end

-- ─── Launcher ──────────────────────────────────────────────────────────────
-- Press the same keys again to close. Inside rofi: type to filter, Enter to
-- open, Escape to close.
if s.launcher then
    B.launcher_apps    = hl.bind(mod .. " + Space", lx("launcher apps"))
    B.launcher_windows = hl.bind(mod .. " + Tab",   lx("launcher windows"))
end

-- ─── Notifications ─────────────────────────────────────────────────────────
if s.notifications then
    B.notify_panel = hl.bind(mod .. " + N",         lx("notify panel"))
    B.notify_dnd   = hl.bind(mod .. " + SHIFT + N", lx("notify dnd"))
end

-- ─── Wallpaper ─────────────────────────────────────────────────────────────
if s.wallpaper then
    B.wallpaper_pick   = hl.bind(mod .. " + W",         lx("wallpaper pick"))
    B.wallpaper_random = hl.bind(mod .. " + SHIFT + W", lx("wallpaper random"))
end

-- ─── Lock ──────────────────────────────────────────────────────────────────
-- `locked = true` makes this key work WHILE the screen is locked, too. If
-- the lock screen app ever crashes, the session stays locked, and pressing
-- this starts a fresh lock screen. `lx lock` does nothing if one is already
-- running. (Needs misc.allow_session_lock_restore; see looks.lua.)
if s.lock then
    B.lock = hl.bind(mod .. " + ALT + L", lx("lock"), { locked = true })
end

-- ─── Theme ─────────────────────────────────────────────────────────────────
if s.theme then
    B.theme_mode = hl.bind(mod .. " + SHIFT + T", lx("theme mode toggle"))
end

-- ─── Screenshots ───────────────────────────────────────────────────────────
-- Every screenshot is saved to ~/Pictures/Screenshots AND copied, ready to paste.
if s.screenshots then
    B.shot_region       = hl.bind("Print",               lx("screenshot region"))
    B.shot_screen       = hl.bind("SHIFT + Print",       lx("screenshot screen"))
    B.shot_window       = hl.bind("CTRL + Print",        lx("screenshot window"))
    -- The same region screenshot, for keyboards without a Print key.
    B.shot_region_alt   = hl.bind(mod .. " + SHIFT + P", lx("screenshot region"))
end

-- ─── Clipboard history ─────────────────────────────────────────────────────
-- SUPER + SHIFT + V, because SUPER + V is already "toggle floating".
if s.clipboard then
    B.clipboard = hl.bind(mod .. " + SHIFT + V", lx("clipboard pick"))
end

-- ─── Power menu ────────────────────────────────────────────────────────────
if s.power_menu then
    B.power_menu = hl.bind(mod .. " + Escape", lx("power menu"))
end

-- ─── Media & hardware keys ─────────────────────────────────────────────────
-- `locked = true` keeps these working while the screen is locked, which is
-- what you want for volume. `repeating = true` lets you hold them down.
B.vol_up   = hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
B.vol_down = hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
B.vol_mute = hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
B.mic_mute = hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })

B.bright_up   = hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
B.bright_down = hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

return B
