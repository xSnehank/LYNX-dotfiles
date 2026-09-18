-- LYNX :: window rules
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- Kept deliberately small. Window rules are where dotfiles repos accumulate
-- cruft for applications you don't have installed. Add yours in
-- ~/.config/hypr/hyprland.lua; rules there apply alongside these.
--
-- Every rule returns a handle, so you can switch one of ours off:
--     local lynx = require("hypr.core")
--     lynx.rules.suppress_maximize:set_enabled(false)

local R = {}

-- Ignore maximize requests from applications. Without this, apps that ask to
-- be maximized on launch fight the tiling layout.
R.suppress_maximize = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Works around drag-and-drop breakage in XWayland apps. Straight from
-- Hyprland's own shipped example config.
R.fix_xwayland_drags = hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- ─── Blur behind notifications (piece 4) ───────────────────────────────────
-- swaync's panel and popups are slightly translucent, so blur what's behind
-- them -- but only when blur is on globally (s.blur, the first thing to turn
-- off if the GPU struggles). The names are the layer-shell namespaces swaync
-- sets in its own source. ignore_alpha = 0.5 leaves nearly transparent
-- pixels, like rounded corners, unblurred.
local s = require("hypr.settings")
if s.blur then
    R.blur_notification_popups = hl.layer_rule({
        name         = "blur-swaync-popups",
        match        = { namespace = "swaync-notification-window" },
        blur         = true,
        ignore_alpha = 0.5,
    })
    R.blur_notification_panel = hl.layer_rule({
        name         = "blur-swaync-panel",
        match        = { namespace = "swaync-control-center" },
        blur         = true,
        ignore_alpha = 0.5,
    })
end

return R
