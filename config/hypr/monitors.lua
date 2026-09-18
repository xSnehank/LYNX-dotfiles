-- LYNX :: monitors
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- DELIBERATELY MINIMAL. Monitor layout is the most machine-specific thing in
-- any dotfiles repo -- resolutions, refresh rates and positions are yours, not
-- LYNX's. Putting a real layout here would mean every `git pull` fights your
-- hardware.
--
-- This is a catch-all that makes any display come up at its preferred mode.
-- Override it in ~/.config/hypr/hyprland.lua:
--
--     hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
--     hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "2560x0", scale = 1 })
--
-- Find your output names with:  hyprctl monitors

hl.monitor({
    output   = "",           -- empty = applies to every output
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
