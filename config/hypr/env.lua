-- LYNX :: environment variables
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

local s = require("hypr.settings")

-- Cursor size must be set in BOTH, or you get a giant X-cursor in XWayland
-- apps and a correctly-sized one everywhere else.
hl.env("XCURSOR_SIZE",     tostring(s.cursor_size))
hl.env("HYPRCURSOR_SIZE",  tostring(s.cursor_size))

-- Your terminal, for tools that look it up in the environment. rofi opens
-- apps that need a terminal through rofi-sensible-terminal, which tries
-- $TERMINAL first. Change it in one place: s.terminal.
hl.env("TERMINAL", s.terminal)

-- Whether colors follow the wallpaper, for `lx` (a shell script, which can't
-- read this Lua). Anything Hyprland launches inherits it.
hl.env("LYNX_THEME", s.theme and "on" or "off")
