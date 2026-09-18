#!/bin/sh
# Smoke tests for bin/lx. Run them on Linux, or in Git Bash on Windows:
#
#   sh tests/smoke_lx.sh
#
# Graphical and system programs are replaced by tiny fakes on PATH that print
# known output. What gets tested is lx's own logic: parsing, markup escaping,
# caching, the files it writes, and the guards it applies.

set -u
# The repo is whatever folder this tests/ directory sits in.
REPO=$(cd "$(dirname "$0")/.." && pwd -P)
LX="$REPO/bin/lx"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home" "$T/walls/a/.git" "$T/walls/b"

export PATH="$T/bin:$PATH"
export HOME="$T/home"
export LYNX_WALLPAPER_DIR="$T/walls"
export LYNX_DIR="$REPO"
export LXTEST_DIR="$T"
C="$T/home/.cache/lynx"

pass=0
fail=0
check() {
    name=$1
    shift
    if "$@" >/dev/null 2>&1; then
        pass=$((pass + 1)); echo "  PASS  $name"
    else
        fail=$((fail + 1)); echo "  FAIL  $name"
    fi
}
has() { printf '%s' "$1" | grep -qF -- "$2"; }
lacks() { ! printf '%s' "$1" | grep -qF -- "$2"; }
show() { printf '%s\n' "$1" | sed 's/^/        | /'; }

stub() {
    printf '#!/bin/sh\n%s\n' "$2" >"$T/bin/$1"
    chmod +x "$T/bin/$1"
}

# ─── fakes ──────────────────────────────────────────────────────────────────
stub curl 'printf "%s\n" "⛅️  |+21°C|Partly cloudy|+19°C|60%|↙12km/h|Berlin, Germany"'
stub hyprctl '
case "$1" in
    activeworkspace) printf "{\n    \"id\": 1,\n    \"name\": \"1\",\n    \"monitor\": \"DP-1\",\n    \"monitorID\": 0\n}\n" ;;
    version) echo "Hyprland 0.56.2 built from branch v0.56.2 at commit abc123" ;;
    hyprpaper) echo "$*" >>"$LXTEST_DIR/hyprctl.log" ;;
esac'
stub hyprlock 'echo "$*" >"$LXTEST_DIR/hyprlock.args"'
stub hyprpaper 'exit 0'
stub pgrep 'case "$2" in hyprpaper) exit 0 ;; *) exit 1 ;; esac'
stub pkill 'echo "pkill $*" >>"$LXTEST_DIR/pkill.log"'
stub setsid 'exit 0'
stub playerctl '
case "$1 ${2:-}" in
    "metadata title") echo "Rock & Roll <Live>" ;;
    "metadata artist") echo "Some Artist" ;;
    "status ") echo Playing ;;
esac'
stub swaync-client 'echo 3'
# A filesystem name containing a space: lx must find the use% column from the
# end of the line, not by counting from the front.
stub df 'printf "Filesystem 1024-blocks Used Available Capacity Mounted on\n//nas/my share 1000 610 390 61%% /\n"'
stub systemctl '
case "$2" in
    show-environment) echo "WAYLAND_DISPLAY=wayland-1" ;;
    start) echo "$3" >"$LXTEST_DIR/systemctl.started" ;;
esac'

# ─── usage ──────────────────────────────────────────────────────────────────
echo "[usage]"
out=$(sh "$LX" help)
check "lists wallpaper commands" has "$out" "lx wallpaper fetch"
check "lists lock commands" has "$out" "lx lock info PANEL"

# ─── weather ────────────────────────────────────────────────────────────────
echo "[weather]"
sh "$LX" lock weather-refresh "Berlin"
out=$(sh "$LX" lock info weather "Berlin")
show "$out"
check "temperature + condition" has "$out" "21°C  Partly cloudy"
check "leading + removed" lacks "$out" "+21"
check "feels like" has "$out" "Feels like 19°C"
check "humidity + wind" has "$out" "Humidity 60%  Wind ↙12km/h"
check "location" has "$out" "Berlin, Germany"

out=$(sh "$LX" lock info weather "Nowhere")
check "no cache yet -> placeholder" has "$out" "Not available yet"

stub curl 'echo "Unknown location; please try ~Berlin"'
sh "$LX" lock weather-refresh "Bad Place"
out=$(sh "$LX" lock info weather "Bad Place")
check "error page is not cached" has "$out" "Not available yet"

# ─── media / notifications / fetch / resources ──────────────────────────────
echo "[panels]"
out=$(sh "$LX" lock info media)
show "$out"
check "media title escaped for Pango" has "$out" "Rock &amp; Roll &lt;Live&gt;"
check "media artist" has "$out" "Some Artist"
out=$(sh "$LX" lock info media-button)
check "play/pause button prints a glyph" test -n "$out"

out=$(sh "$LX" lock info notifications)
show "$out"
check "notification count, no content" has "$out" "3 notifications"

out=$(sh "$LX" lock info fetch)
show "$out"
check "fetch header" has "$out" "&gt; lynxfetch"
check "fetch compositor version" has "$out" "WM   Hyprland 0.56.2"

out=$(sh "$LX" lock info resources)
show "$out"
check "resources: cpu line" has "$out" "CPU"
check "resources: ram line" has "$out" "RAM"
check "resources: disk line" has "$out" "DISK"
check "resources: bars" has "$out" "▰"
check "disk use% read from the end of the line" has "$out" " 61%"
check "no percentage above 100" sh -c 'printf "%s\n" "$1" | grep -oE "[0-9]+%" | tr -d % | awk "\$1 > 100 { bad = 1 } END { exit bad }"' _ "$out"

out=$(sh "$LX" lock info nonsense 2>&1)
check "unknown panel is refused" has "$out" "usage: lx lock info"

# ─── lock ───────────────────────────────────────────────────────────────────
echo "[lock]"
WAYLAND_DISPLAY=wayland-1 sh "$LX" lock idle
check "idle lock passes --grace 5" grep -qx -- "--grace 5" "$T/hyprlock.args"
check "lock-session.conf names the focused monitor" grep -qx '$lx_monitor = DP-1' "$C/lock-session.conf"
check "palette copied into the cache" cmp -s "$C/colors-hyprlock.conf" "$REPO/config/hyprlock/fallback-colors.conf"

rm -f "$T/hyprlock.args"
WAYLAND_DISPLAY=wayland-1 sh "$LX" lock
check "manual lock has no grace period" test "$(cat "$T/hyprlock.args")" = ""

stub pgrep 'case "$2" in hyprlock|hyprpaper) exit 0 ;; *) exit 1 ;; esac'
rm -f "$T/hyprlock.args"
WAYLAND_DISPLAY=wayland-1 sh "$LX" lock
check "already locked -> no second hyprlock" test ! -e "$T/hyprlock.args"
stub pgrep 'case "$2" in hyprpaper) exit 0 ;; *) exit 1 ;; esac'

# ─── services ───────────────────────────────────────────────────────────────
echo "[services]"
WAYLAND_DISPLAY=wayland-1 sh "$LX" service start hypridle
check "starts the unit once the env is there" grep -qx hypridle "$T/systemctl.started"
out=$(env -u WAYLAND_DISPLAY sh "$LX" service start hypridle 2>&1)
check "refuses outside a Wayland session" has "$out" "not running inside a Wayland session"

# ─── wallpaper ──────────────────────────────────────────────────────────────
echo "[wallpaper]"
for f in a/one.jpg a/.git/hidden.jpg b/two.PNG b/anim.gif; do : >"$T/walls/$f"; done

i=0
while [ "$i" -lt 25 ]; do
    sh "$LX" wallpaper random >/dev/null 2>&1
    i=$((i + 1))
done
log=$(cat "$T/hyprctl.log" 2>/dev/null || true)
check "random switches through hyprctl" has "$log" "hyprpaper wallpaper ,"
check "never picks files inside .git" lacks "$log" "hidden.jpg"
check "never picks a GIF" lacks "$log" "anim.gif"
check "no spaces in the monitor,path,fit argument" has "$log" ",cover"
check "current wallpaper recorded" test -e "$C/wallpaper/current"

: >"$T/walls/b/bad,name.jpg"
out=$(sh "$LX" wallpaper set "$T/walls/b/bad,name.jpg" 2>&1)
check "comma in file name is refused" has "$out" "containing a comma"
out=$(sh "$LX" wallpaper set "$T/walls/b/anim.gif" 2>&1)
check "unsupported format is refused" has "$out" "can't show this format"
out=$(sh "$LX" wallpaper set "$T/walls/nope.jpg" 2>&1)
check "missing file is refused" has "$out" "no such file"

rm -f "$C/wallpaper/lock.jpg"
sh "$LX" wallpaper lock-image "$T/walls/a/one.jpg" 2>/dev/null
check "lock image made from a jpg (no imagemagick needed)" test -e "$C/wallpaper/lock.jpg"

rm -rf "$C/wallpaper"
sh "$LX" wallpaper start >/dev/null 2>&1
check "first start falls back to the LYNX default" test -e "$C/wallpaper/current"

# ─── theme ──────────────────────────────────────────────────────────────────
echo "[theme]"
export LXTEST_RENDER="$(cd "$(dirname "$0")" && pwd)/render_templates.py"
LXTEST_PY=${LYNX_PYTHON:-$(command -v python3 || command -v python || echo python3)}
export LXTEST_PY
export HYPRLAND_INSTANCE_SIGNATURE=test
export LYNX_THEME=on
rm -f "$T/reload.log" "$T/notify.log" "$T/setsid.log"

stub matugen 'LXTEST_HOME="$(cygpath -w "$HOME" 2>/dev/null || echo "$HOME")" exec "$LXTEST_PY" "$LXTEST_RENDER" "$@"'
stub pgrep 'case "$2" in hyprpaper|waybar|kitty) exit 0 ;; *) exit 1 ;; esac'
stub pkill 'echo "pkill $*" >>"$LXTEST_DIR/reload.log"'
stub swaync-client 'echo "swaync-client $*" >>"$LXTEST_DIR/reload.log"; echo 3'
stub hyprctl '
case "$1" in
    reload) echo "hyprctl reload" >>"$LXTEST_DIR/reload.log" ;;
    hyprpaper) echo "$*" >>"$LXTEST_DIR/hyprctl.log" ;;
    activeworkspace) printf "{\n    \"monitor\": \"DP-1\"\n}\n" ;;
esac'
stub notify-send 'echo "$*" >>"$LXTEST_DIR/notify.log"'
stub setsid 'shift; echo "$*" >>"$LXTEST_DIR/setsid.log"'

sh "$LX" wallpaper set "$T/walls/a/one.jpg" >/dev/null 2>&1
check "changing wallpaper starts a theme reload" grep -q "theme reload" "$T/setsid.log"

sh "$LX" theme reload
rc=$?
check "reload succeeds" test "$rc" -eq 0
for f in colors.css colors.rasi colors-gtk4.css colors-hyprlock.conf colors-kitty.conf colors.lua; do
    check "generated $f installed" grep -q "Rendered by matugen" "$C/$f"
done
check "staging left empty" sh -c '[ -z "$(ls -A "$1")" ]' _ "$C/theme/staging"
# lx records where ~/.cache/lynx/wallpaper/current points. That needs real
# symlinks; Git Bash on Windows makes copies for `ln -s` by default, so this
# check only means something where symlinks work (Linux does).
: >"$T/linktest.jpg"
ln -sfn "$T/linktest.jpg" "$T/linktest"
if [ -L "$T/linktest" ]; then
    check "remembers which wallpaper the colors came from" grep -q "one.jpg" "$C/theme/source"
else
    echo "  SKIP  remembers which wallpaper the colors came from (ln -s makes copies here, not symlinks)"
fi
check "matugen gets the mode" grep -q -- "--mode dark" "$T/matugen.args"
check "matugen never has to ask for a color" grep -q -- "--source-color-index 0" "$T/matugen.args"
check "Waybar reloads its style" grep -q "pkill -USR2 -x waybar" "$T/reload.log"
check "kitty reloads its colors" grep -q "pkill -USR1 -x kitty" "$T/reload.log"
check "swaync reloads its style" grep -q "swaync-client -rs -sw" "$T/reload.log"
check "Hyprland reloads (borders)" grep -q "hyprctl reload" "$T/reload.log"

cp "$C/colors.css" "$T/before.css"
cp "$C/colors-gtk4.css" "$T/before-gtk4.css"
LXTEST_MATUGEN=fail sh "$LX" theme reload
rc=$?
check "matugen failing -> reported as failure" test "$rc" -ne 0
check "matugen failing -> colors untouched" cmp -s "$C/colors.css" "$T/before.css"
check "matugen failing -> you're told" grep -q "matugen failed" "$T/notify.log"

LXTEST_MATUGEN=bad sh "$LX" theme reload
rc=$?
check "incomplete render -> reported as failure" test "$rc" -ne 0
check "incomplete render -> the broken file isn't installed" cmp -s "$C/colors-gtk4.css" "$T/before-gtk4.css"
check "incomplete render -> nothing else is installed either" cmp -s "$C/colors.css" "$T/before.css"
check "incomplete render -> you're told" grep -q "incomplete" "$T/notify.log"

sh "$LX" theme mode toggle >/dev/null 2>&1
check "mode toggles to light" grep -qx light "$C/theme/mode"
check "matugen gets the new mode" grep -q -- "--mode light" "$T/matugen.args"

sh "$LX" theme scheme vibrant >/dev/null 2>&1
check "scheme is remembered" grep -qx scheme-vibrant "$C/theme/scheme"
check "matugen gets the scheme" grep -q -- "--type scheme-vibrant" "$T/matugen.args"
out=$(sh "$LX" theme scheme purple 2>&1)
check "unknown scheme is refused" has "$out" "usage: lx theme scheme"
check "unknown scheme isn't stored" grep -qx scheme-vibrant "$C/theme/scheme"

cp "$T/matugen.args" "$T/args.before"
mkdir "$C/theme/.running"
sh "$LX" theme reload
rc=$?
check "already running -> returns at once" test "$rc" -eq 0
check "already running -> request remembered" test -e "$C/theme/.again"
check "already running -> no second matugen" cmp -s "$T/matugen.args" "$T/args.before"
rmdir "$C/theme/.running"
rm -f "$C/theme/.again"

out=$(LYNX_THEME=off sh "$LX" theme reload 2>&1)
check "theming off -> reload refused" has "$out" "theming is off"

rm -f "$C/colors-kitty.conf"
sh "$LX" theme ensure
check "ensure restores a missing palette" cmp -s "$C/colors-kitty.conf" "$REPO/config/kitty/fallback-colors.conf"
check "ensure leaves generated palettes alone" grep -q "Rendered by matugen" "$C/colors.css"

sh "$LX" theme reset >/dev/null 2>&1
check "reset -> fallback palette back" cmp -s "$C/colors.css" "$REPO/config/waybar/fallback-colors.css"
check "reset -> generated border colors removed" test ! -e "$C/colors.lua"
out=$(sh "$LX" theme status)
show "$out"
check "status reflects the reset" has "$out" "LYNX fallback palette"

# ─── tools: screenshots, clipboard, power ───────────────────────────────────
echo "[tools]"
rm -f "$T/grim.log" "$T/slurp.log" "$T/clip.log" "$T/notify.log" "$T/setsid.log" \
      "$T/satty.log" "$T/cliphist.log" "$T/rofi.log" "$T/power.log" "$T/rofi.answers"
SHOTS="$HOME/Pictures/Screenshots"

# grim: log the arguments, create the output file.
stub grim '
echo "$*" >>"$LXTEST_DIR/grim.log"
for last; do :; done
[ "$last" = - ] || printf PNG >"$last"'
stub slurp '
echo "$*" >>"$LXTEST_DIR/slurp.log"
[ "${LXTEST_SLURP:-}" = cancel ] && exit 1
echo "10,20 300x200"'
stub wl-copy 'cat >/dev/null; echo "wl-copy $*" >>"$LXTEST_DIR/clip.log"'
# lx checks wl-paste exists before starting the watchers; the watchers
# themselves are launched through the setsid fake, which only logs them.
stub wl-paste 'exit 0'
stub notify-send '
echo "$*" >>"$LXTEST_DIR/notify.log"
[ -n "${LXTEST_NOTIFY_ACTION:-}" ] && echo "$LXTEST_NOTIFY_ACTION"
exit 0'
stub satty 'echo "$*" >>"$LXTEST_DIR/satty.log"'
stub setsid 'shift; echo "$*" >>"$LXTEST_DIR/setsid.log"'
stub hyprctl '
case "$1" in
    monitors)
        printf "[{\n    \"id\": 0,\n    \"name\": \"DP-1\",\n    \"activeWorkspace\": {\n        \"id\": 1,\n        \"name\": \"1\"\n    },\n    \"focused\": false\n},{\n    \"id\": 1,\n    \"name\": \"HDMI-A-1\",\n    \"activeWorkspace\": {\n        \"id\": 2,\n        \"name\": \"2\"\n    },\n    \"focused\": true\n}]\n" ;;
    activewindow)
        if [ "${LXTEST_NOWINDOW:-}" = 1 ]; then echo "Invalid"; else
        printf "{\n    \"address\": \"0x1\",\n    \"at\": [120, 45],\n    \"size\": [800, 600],\n    \"workspace\": {\n        \"id\": 1\n    }\n}\n"; fi ;;
    activeworkspace) printf "{\n    \"monitor\": \"DP-1\"\n}\n" ;;
    dispatch) echo "hyprctl $*" >>"$LXTEST_DIR/power.log" ;;
esac'
stub cliphist '
case "$1" in
    list) printf "2\tsecond copy\n1\tfirst copy\n" ;;
    decode) read -r line; echo "decode $line" >>"$LXTEST_DIR/cliphist.log"; echo "decoded" ;;
    delete) read -r line; echo "delete $line" >>"$LXTEST_DIR/cliphist.log" ;;
    wipe) echo "wipe" >>"$LXTEST_DIR/cliphist.log" ;;
esac'
# rofi: answers come from a queue file, one "EXITCODE|TEXT" per call.
stub rofi '
echo "$*" >>"$LXTEST_DIR/rofi.log"
cat >/dev/null
line=$(head -n 1 "$LXTEST_DIR/rofi.answers" 2>/dev/null)
sed -i 1d "$LXTEST_DIR/rofi.answers" 2>/dev/null
rc=${line%%|*}
text=${line#*|}
[ -n "$line" ] && [ -n "$text" ] && printf "%b\n" "$text"
exit "${rc:-1}"'
stub hyprshutdown 'echo "hyprshutdown $*" >>"$LXTEST_DIR/power.log"'
stub systemctl '
case "$2" in
    show-environment) echo "WAYLAND_DISPLAY=wayland-1" ;;
    start) echo "$3" >"$LXTEST_DIR/systemctl.started" ;;
    *) echo "systemctl $*" >>"$LXTEST_DIR/power.log" ;;
esac'
stub pgrep 'case "$2" in hyprpaper|waybar|kitty) exit 0 ;; *) exit 1 ;; esac'
answer() { printf '%s\n' "$1" >>"$T/rofi.answers"; }

# Screenshots
sh "$LX" screenshot region
check "region: grim gets slurp's rectangle" grep -q -- "-g 10,20 300x200" "$T/grim.log"
check "region: saved into ~/Pictures/Screenshots" sh -c 'ls "$1"/*.png >/dev/null 2>&1' _ "$SHOTS"
check "region: copied as an image" grep -q "wl-copy --type image/png" "$T/clip.log"
check "region: notification runs in the background" grep -q "screenshot notify" "$T/setsid.log"
check "region: selection uses the palette accent" grep -q -- "-c #89b4faff" "$T/slurp.log"

before=$(wc -l <"$T/grim.log")
LXTEST_SLURP=cancel sh "$LX" screenshot region
rc=$?
check "region cancelled: no error" test "$rc" -eq 0
check "region cancelled: nothing captured" test "$(wc -l <"$T/grim.log")" -eq "$before"

sh "$LX" screenshot screen
check "screen: the focused monitor, not the first" grep -q -- "-o HDMI-A-1" "$T/grim.log"
sh "$LX" screenshot window
check "window: the focused window's geometry" grep -q -- "-g 120,45 800x600" "$T/grim.log"
LXTEST_NOWINDOW=1 sh "$LX" screenshot window 2>/dev/null
rc=$?
check "no focused window: fails" test "$rc" -ne 0
check "no focused window: you're told" grep -q "No focused window" "$T/notify.log"

check "same-second screenshots don't overwrite" sh -c '[ "$(ls "$1"/*.png | wc -l)" -ge 3 ]' _ "$SHOTS"

shot=$(ls "$SHOTS"/*.png | head -n 1)
LXTEST_NOTIFY_ACTION=edit sh "$LX" screenshot notify "$shot"
check "Edit opens satty on that screenshot" grep -qF -- "--filename $shot" "$T/satty.log"
check "Edit never overwrites the original" grep -q -- "-edited.png" "$T/satty.log"

out=$(env PATH="$(printf '%s' "$PATH" | sed "s#$T/bin:##")" sh "$LX" screenshot region 2>&1)
check "grim missing: says how to install it" has "$out" "sudo pacman -S grim"

# Clipboard
sh "$LX" clipboard start
check "records text copies" grep -q "wl-paste --type text --watch cliphist store" "$T/setsid.log"
check "records image copies" grep -q "wl-paste --type image --watch cliphist store" "$T/setsid.log"

answer '0|2\tsecond copy'
sh "$LX" clipboard pick
check "pick: the chosen entry is decoded" grep -qF "$(printf 'decode 2\tsecond copy')" "$T/cliphist.log"
check "pick: and copied again" grep -q "wl-copy" "$T/clip.log"
check "pick: Alt+D is the delete key" grep -q -- "-kb-custom-1 Alt+d" "$T/rofi.log"

answer '10|1\tfirst copy'
answer '1|'
sh "$LX" clipboard pick
check "Alt+D deletes that entry" grep -qF "$(printf 'delete 1\tfirst copy')" "$T/cliphist.log"
check "after deleting, the list reopens" test "$(grep -c -- '-p Clipboard' "$T/rofi.log")" -eq 3

answer '0|Cancel'
sh "$LX" clipboard wipe
check "wipe asks, Cancel keeps history" sh -c '! grep -q wipe "$1"' _ "$T/cliphist.log"
answer '0|Forget everything'
sh "$LX" clipboard wipe
check "wipe confirmed forgets everything" grep -q wipe "$T/cliphist.log"
check "confirmations start on Cancel" grep -q -- "-selected-row 1" "$T/rofi.log"

# Power menu
answer '0|x  Lock'
WAYLAND_DISPLAY=wayland-1 sh "$LX" power menu
check "Lock locks" test -e "$T/hyprlock.args"

answer '0|x  Suspend'
sh "$LX" power menu
check "Suspend suspends (no question)" grep -q "systemctl suspend" "$T/power.log"

answer '0|x  Restart'
answer '0|Cancel'
sh "$LX" power menu
check "Restart + Cancel does nothing" sh -c '! grep -q reboot "$1"' _ "$T/power.log"

answer '0|x  Restart'
answer '0|Restart'
sh "$LX" power menu
check "Restart confirmed: apps closed first, then reboot" grep -q "hyprshutdown --top-label Restarting… --post-cmd systemctl reboot" "$T/power.log"

answer '0|x  Log out'
answer '0|Log out'
sh "$LX" power menu
check "Log out confirmed: graceful exit, no reboot" grep -qx "hyprshutdown --top-label Logging out…" "$T/power.log"

rm -f "$T/bin/hyprshutdown"
answer '0|x  Shut down'
answer '0|Shut down'
sh "$LX" power menu
check "without hyprshutdown: still powers off" grep -q "systemctl poweroff" "$T/power.log"

answer '0|x  Log out'
answer '0|Log out'
sh "$LX" power menu
check "without hyprshutdown: log out exits Hyprland" grep -qF "hyprctl dispatch hl.dsp.exit()" "$T/power.log"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
