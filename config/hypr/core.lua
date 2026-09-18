-- LYNX :: core
--
-- The entry point. Your ~/.config/hypr/hyprland.lua requires this, and this
-- requires everything else in a deliberate order.
--
-- Returns a table of handles so you can selectively DISABLE things from your
-- own config instead of forking this repo:
--
--     local lynx = require("hypr.core")
--     lynx.binds.terminal:set_enabled(false)
--     hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))

local M = {}

require("hypr.env")        -- env vars first: they affect everything after
require("hypr.monitors")   -- safe fallback only; real layout is yours
require("hypr.input")
require("hypr.looks")      -- general / decoration / animations
M.rules = require("hypr.rules")
M.binds = require("hypr.keybinds")
require("hypr.autostart")  -- last: don't launch anything until config is sane

return M
