-- LYNX :: look and feel
-- https://wiki.hypr.land/Configuring/Basics/Variables/
--
-- THIS FILE CONTAINS NO HARDCODED COLORS.
--
-- It loads a palette from ~/.cache/lynx/colors.lua, which matugen regenerates
-- every time the wallpaper changes. If that file doesn't exist yet (fresh
-- install, or you just deleted the cache), we fall back to the defaults in
-- settings.lua instead of failing.
--
-- That pcall is doing real work: under the old hyprlang config a `source =`
-- pointing at a missing file was a hard error, which is exactly how a first
-- boot ends up at a black screen. Lua lets us degrade gracefully instead.

local s = require("hypr.settings")

local function load_palette()
    -- Theming switched off in settings: always the fixed palette.
    if not s.theme then return s.colors end

    local home = os.getenv("HOME")
    if not home then return s.colors end

    local ok, cached = pcall(dofile, home .. "/.cache/lynx/colors.lua")
    if ok and type(cached) == "table" and cached.active_border then
        return cached
    end
    return s.colors
end

local c = load_palette()

hl.config({
    general = {
        gaps_in     = s.gaps_in,
        gaps_out    = s.gaps_out,
        border_size = s.border_size,

        col = {
            active_border   = c.active_border,
            inactive_border = c.inactive_border,
        },

        resize_on_border = true,   -- drag borders/gaps to resize
        allow_tearing    = false,  -- see the Tearing wiki page before enabling
        layout           = s.layout,
    },

    decoration = {
        rounding         = s.rounding,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = s.shadow,
            range        = 4,
            render_power = 3,
            color        = c.shadow,
        },

        blur = {
            enabled  = s.blur,
            size     = s.blur_size,
            passes   = s.blur_passes,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = s.animations,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        -- Don't fetch or draw Hyprland's default wallpapers. We manage our own.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,

        -- If the lock screen app crashes, Hyprland keeps the session locked
        -- and shows a warning. With this on, a NEW lock screen can take over
        -- that locked session (SUPER + ALT + L works while locked), instead
        -- of you having to kill the whole session to get back in. It never
        -- unlocks anything by itself.
        allow_session_lock_restore = true,
    },
})

-- Animation curves and timings.
-- These are Hyprland's shipped defaults, kept verbatim because they're tuned
-- and known-good. Adjust speeds from your own config if you want it snappier.
if s.animations then
    hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
    hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
    hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
    hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
    hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
    hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

    hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
    hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
    hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
    hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
    hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
    hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
    hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
    hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
    hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
    hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
end
