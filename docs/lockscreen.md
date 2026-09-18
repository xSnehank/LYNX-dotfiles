# Lock screen

LYNX's lock screen is **hyprlock**, laid out after Caelestia's lock screen.
Caelestia's is QML code inside its Quickshell shell (`modules/lock/` in
caelestia-dots/shell) and can't run on this stack. This is a rebuild of the
design, not a port of any file.

## Layout

```
┌──────────────┐                                    ┌──────────────┐
│ weather      │               14                   │ resources    │
├──────────────┤               37                   │ CPU RAM DISK │
│ lynxfetch    │        FRIDAY • 12 SEP             ├──────────────┤
│ OS WM USER UP│             ( you )                │ notifications│
├──────────────┤        [   password   ]            │ (count only) │
│ media ⏮ ⏯ ⏭ │     fingerprint · layout           └──────────────┘
└──────────────┘
```

The center column appears on every monitor. The side panels appear on the
monitor that was focused when the screen locked.

## Compared to Caelestia

**Kept:** the three-column layout; the big stacked clock, date and profile
picture (`~/.face`); weather, fetch, media, resources and notification panels;
password plus fingerprint; clickable media controls.

**Better, and why:**

| | LYNX | Why it matters |
|---|---|---|
| Separate process | hyprlock is its own program | A bug in the bar, launcher or any other widget can't take the lock screen down with it. In Caelestia the lock is part of the same shell process. |
| Crash recovery | Hyprland's `allow_session_lock_restore` is on, and `SUPER + ALT + L` works *while locked* | If the lock app ever crashes, the session stays locked and one key starts a fresh lock screen. You don't have to kill the session. |
| Lock before sleep | hypridle `inhibit_sleep = 3` | Sleep is held until the session is actually locked, so your desktop never flashes on wake. |
| Notification privacy | Count only | Caelestia lists which apps notified you unless you turn on `hideNotifs`. LYNX never shows who or what on the lock screen. |
| Weather privacy | One service (wttr.in), location you can set, panel removable | Caelestia looks up your location from your IP via `http://ip-api.com`, unencrypted, then reverse-geocodes with OpenStreetMap. |
| Instant appearance | Pre-resized `lock.jpg` + `immediate_render` | The lock appears immediately even with an 8K wallpaper. |
| Typing hints | Caps Lock turns the field outline yellow; a non-default keyboard layout is shown | The two usual reasons a correct password "fails". |
| Customizing | Each panel is one `source =` line; bad config lines are skipped, not fatal | Remove a panel by commenting one line. A typo can't leave you without a lock screen. |

**Not matched — hyprlock can't do these:**

- **The morphing open/unlock animation.** hyprlock can fade in and out and
  animate the password field, but it can't scale or reshape widgets.
- **Album art, the hourly forecast, and circular gauges.** Resources are text
  bars instead.
- **Face unlock (howdy).** Caelestia supports it through PAM. howdy is only in
  the AUR, so LYNX doesn't set it up.

## Customizing

Everything is in `~/.config/hypr/hyprlock.conf`, and every knob is explained
in `config/hyprlock/defaults.conf`:

```ini
$lx_weather_location = Berlin
$lx_avatar = $HOME/Pictures/me.png
$lx_fingerprint = false
```

To remove a panel, comment out its `source =` line.

Try changes without risk:

```bash
hyprlock --grace 60
```

For 60 seconds, moving the mouse dismisses it without a password.

## Locking

| How | Grace period |
|---|---|
| `SUPER + ALT + L` | none |
| 5 minutes idle (`~/.config/hypr/hypridle.conf`) | 5 seconds: move the mouse to cancel |
| Before suspend | none, and sleep waits for the lock |

## If something goes wrong

**The lock screen crashed** (Hyprland shows its "lock screen died" message).
Press `SUPER + ALT + L`. If that doesn't respond, switch to a TTY
(`Ctrl + Alt + F2`), log in, and run:

```bash
hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("sh ~/dotfiles/lynx/bin/lx lock")'
```

Then switch back with `Ctrl + Alt + F1` and unlock normally.

**Wrong password three times** and now nothing works. That's Arch's
`pam_faillock`: 10 minutes locked out, and the message appears under the
password field. It's a system policy, not LYNX. See the Arch wiki page
"Security", section "Lock out user after three failed login attempts".

**A panel shows nothing.** Run its command yourself, e.g.
`sh ~/dotfiles/lynx/bin/lx lock info resources`, and see what it prints.
hyprlock's own log is `~/.cache/lynx/hyprlock.log`.
