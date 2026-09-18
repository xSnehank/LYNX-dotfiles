# Screenshots, clipboard history, power menu

## Screenshots

| Keys | What it captures |
|---|---|
| `Print` | A region: drag a rectangle. Escape cancels. |
| `SUPER + SHIFT + P` | The same, for keyboards without a Print key |
| `SHIFT + Print` | The monitor you're on |
| `CTRL + Print` | The focused window |

Every screenshot is **both** saved and copied: ready to paste straight away,
and still there later.

- **Where:** `~/Pictures/Screenshots` (or your XDG Pictures folder, if you've
  set one), named by date and time, e.g. `2026-09-13_14-05-22.png`.
- **Notification:** shows a preview. If `satty` is installed, it has an
  **Edit** button: draw arrows, boxes, blur or text. In satty, Enter copies the
  edited version and Ctrl+S saves it as `…-edited.png`. The original is never
  overwritten.
- **Different folder:** in `~/.config/hypr/hyprland.lua`,
  `hl.env("LYNX_SCREENSHOT_DIR", os.getenv("HOME") .. "/Desktop")`.

No screen-capture permission prompt: Hyprland 0.56.2 doesn't enforce
capture permissions by default (`ecosystem:enforce_permissions` is off).

**Not included:** freezing the screen while you select a region. That needs a
helper (hyprpicker) holding a full-screen overlay; if it ever gets stuck, your
screen stays frozen until it's killed. Your stated priority is stability, so
LYNX leaves it out.

## Clipboard history

| Keys / command | What it does |
|---|---|
| `SUPER + SHIFT + V` | List earlier copies; Enter copies one again |
| `Alt + D` (inside the list) | Delete that entry |
| `lx clipboard wipe` | Forget everything (asks first) |

Text and images are both recorded, the most recent 750 (cliphist's default),
in `~/.cache/cliphist/db`. Why `SUPER + SHIFT + V` and not `SUPER + V`: that's
already "toggle floating". Swapping them is two lines in your `hyprland.lua`:

```lua
lynx.binds.toggle_float:set_enabled(false)
lynx.binds.clipboard:set_enabled(false)
hl.bind("SUPER + V", hl.dsp.exec_cmd("sh ~/dotfiles/lynx/bin/lx clipboard pick"))
hl.bind("SUPER + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
```

### Passwords — read this

When an app marks something it copies as secret, clipboard history **does not
store it**: wl-clipboard flags the copy as sensitive, and cliphist skips it.
KeePassXC does this.

**Most other apps don't.** A password copied from a browser page, a text file
or a chat is recorded like anything else. If that matters to you:

- use a password manager that marks copies as secret (KeePassXC), or
- delete the entry with `Alt + D` right after using it, or
- turn history off: `s.clipboard = false` in `hyprland.lua`, then
  `lx clipboard wipe`.

## Power menu

| Keys / click | What it does |
|---|---|
| `SUPER + Escape` | Open the power menu |
| Power button in the bar | Same; right-click locks |

**Lock** and **Suspend** happen immediately. Suspend is still safe: hypridle
locks the screen before the machine sleeps.

**Log out**, **Restart** and **Shut down** ask first. The highlighted answer
starts on **Cancel**, so pressing Enter out of habit does nothing.

When confirmed, `hyprshutdown` closes your apps gracefully first, so they
don't simply get killed mid-save. Then Hyprland exits, and then the machine
restarts or powers off. Without hyprshutdown installed, the same thing
happens, but apps are killed along with the session.
