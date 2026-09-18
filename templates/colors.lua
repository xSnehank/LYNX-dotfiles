-- LYNX :: generated palette (Hyprland window borders)
--
-- Rendered by matugen from your wallpaper (lx theme reload). Don't edit this
-- file: it's replaced every time the colors change. config/hypr/looks.lua
-- reads it; if it's missing or broken, looks.lua uses the colors in
-- settings.lua instead.

return {
    -- Focused window: a gradient from the accent to the tertiary color.
    active_border   = { colors = { "rgba({{colors.primary.default.hex_stripped}}ee)", "rgba({{colors.tertiary.default.hex_stripped}}ee)" }, angle = 45 },
    inactive_border = "rgba({{colors.outline.default.hex_stripped}}aa)",
    shadow          = 0xee{{colors.shadow.default.hex_stripped}},
}
