-- LYNX :: autostart
-- https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- Each build piece adds its own line here, so if the session breaks you know
-- exactly which piece did it.
--
-- "hyprland.start" fires once per Hyprland launch. It does NOT fire again on
-- `hyprctl reload`, so nothing in here gets started twice.
--
-- systemd services go through `lx service start` rather than calling
-- systemctl directly: lx first waits until Hyprland has handed WAYLAND_DISPLAY
-- to systemd. Without that wait, a service could be skipped silently at login.
-- The full explanation is in bin/lx.

local s = require("hypr.settings")

-- Run a LYNX CLI command: `sh` plus an absolute path, so this depends on
-- neither PATH nor the executable bit. See s.lynx_dir in settings.lua.
local function run_lx(args)
    hl.exec_cmd("sh '" .. s.lynx_dir .. "/bin/lx' " .. args)
end

hl.on("hyprland.start", function()
    -- Piece 6: make sure every program's palette file exists before anything
    -- that reads one starts. Only fills in missing files; never overwrites.
    run_lx("theme ensure")

    -- Piece 1: polkit authentication agent. Without it, any GUI application
    -- that needs elevated privileges fails with no visible prompt at all.
    run_lx("service start hyprpolkitagent")

    -- Piece 2: the bar. lx first makes sure the color palette file exists;
    -- without it, Waybar refuses to start.
    if s.bar then
        run_lx("bar start")
    end

    -- Piece 4: notifications. swaync would also start by itself when the first
    -- notification arrives (D-Bus activation). Starting it here means that
    -- first notification isn't delayed, and the bar's bell works from login.
    if s.notifications then
        run_lx("service start swaync")
    end

    -- Piece 5: wallpaper. hyprpaper's own systemd unit requires
    -- graphical-session.target, which a TTY-started Hyprland doesn't
    -- activate, so lx starts it directly, like the bar.
    if s.wallpaper then
        run_lx("wallpaper start")
    end

    -- Piece 5: idle daemon. Locks after inactivity, and locks before sleep.
    if s.idle then
        run_lx("service start hypridle")
    end

    -- Piece 7: clipboard history. Copies marked secret by password managers
    -- are not recorded (see docs/tools.md for what that does and doesn't cover).
    if s.clipboard then
        run_lx("clipboard start")
    end
end)
