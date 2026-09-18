-- ~/.config/hypr/hyprland.lua
--
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  THIS FILE IS YOURS.                                                     ║
-- ║  LYNX created it once and will never touch it again. `git pull` in the   ║
-- ║  LYNX repo cannot overwrite anything you write here.                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- There are exactly three things you can do in this file. That's the whole
-- customization model -- there is nothing else to learn.
--
--   1. Change a setting        -> edit the `s.` lines below
--   2. Add something new       -> call hl.* directly, anywhere below
--   3. Switch one of ours off  -> lynx.binds.<name>:set_enabled(false)

-- ─── Point Lua at the LYNX repo ────────────────────────────────────────────
-- No hardcoded username: HOME is resolved at load time. If you moved the repo
-- somewhere other than ~/dotfiles/lynx, this is the one line to change.
local LYNX = os.getenv("HOME") .. "/dotfiles/lynx/config"
package.path = LYNX .. "/?.lua;" .. package.path


-- ─── 1. Settings ───────────────────────────────────────────────────────────
-- Must come BEFORE require("hypr.core"). Core reads these values as it loads,
-- so anything you set afterwards arrives too late to have an effect.
-- Full list of knobs: config/hypr/settings.lua in the repo.

local s = require("hypr.settings")

-- s.terminal   = "kitty"
-- s.mod        = "SUPER"
-- s.gaps_in    = 5
-- s.gaps_out   = 12
-- s.rounding   = 10
-- s.blur       = true      -- set false first if anything ever feels sluggish
-- s.kb_layout  = "us"


-- ─── 2. Load LYNX ──────────────────────────────────────────────────────────
local lynx = require("hypr.core")


-- ─── 3. Your monitors ──────────────────────────────────────────────────────
-- LYNX only ships a catch-all (preferred mode, auto position). Put your real
-- layout here -- it will never be clobbered by an update.
-- Find your output names with:  hyprctl monitors
--
-- hl.monitor({ output = "DP-1",     mode = "2560x1440@165", position = "0x0",    scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",  position = "2560x0", scale = 1 })


-- ─── 4. Your keybinds ──────────────────────────────────────────────────────
-- Add your own freely:
--
--   hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
--
-- Or replace one of LYNX's. Names are the keys of the table returned by
-- config/hypr/keybinds.lua:
--
--   lynx.binds.terminal:set_enabled(false)
--   hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))


-- ─── 5. Your window rules ──────────────────────────────────────────────────
--   hl.window_rule({ name = "float-pavucontrol",
--                    match = { class = "pavucontrol" },
--                    float = true })
--
-- Or switch one of ours off:
--   lynx.rules.suppress_maximize:set_enabled(false)


-- ─── 6. Your autostart ─────────────────────────────────────────────────────
--   hl.on("hyprland.start", function()
--       hl.exec_cmd("nm-applet")
--   end)

return lynx
