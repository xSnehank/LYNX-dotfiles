-- LYNX :: input
-- https://wiki.hypr.land/Configuring/Basics/Variables/

local s = require("hypr.settings")

hl.config({
    input = {
        kb_layout  = s.kb_layout,
        kb_variant = s.kb_variant,
        kb_options = s.kb_options,

        -- 1 = focus follows the mouse. Set to 0 from your config if you'd
        -- rather focus only changes on click.
        follow_mouse = s.follow_mouse,

        sensitivity = s.sensitivity,

        touchpad = {
            natural_scroll = s.natural_scroll,
        },
    },
})

-- Three-finger horizontal swipe changes workspace.
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
