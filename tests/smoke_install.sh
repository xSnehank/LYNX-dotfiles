#!/bin/sh
# Smoke tests for install.sh. Run them on Linux, or in Git Bash on Windows:
#
#   sh tests/smoke_install.sh [SHELL]
#
# SHELL is what runs install.sh (default: sh). Use dash to catch bash-only
# syntax. pacman, sudo, hyprland, fc-list, id, git, curl and setsid are fakes
# on PATH. HOME is a temp folder holding a COPY of the repo at ~/dotfiles/lynx,
# so neither the real repo nor the real ~/.config is ever touched.

set -u
SH=${1:-sh}
# The repo is whatever folder this tests/ directory sits in.
REPO=$(cd "$(dirname "$0")/.." && pwd -P)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export LXTEST_DIR="$T"
export HOME="$T/home"
BASE_PATH="$T/bin:$PATH"
export PATH="$BASE_PATH:$HOME/.local/bin"
unset XDG_CONFIG_HOME LYNX_DIR LYNX_WALLPAPER_DIR
mkdir -p "$T/bin" "$HOME/dotfiles"
cp -r "$REPO" "$HOME/dotfiles/lynx"
rm -rf "$HOME/dotfiles/lynx/.git" # the copy doesn't need the history
COPY="$HOME/dotfiles/lynx"
INSTALL="$COPY/install.sh"

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

stub() {
    printf '#!/bin/sh\n%s\n' "$2" >"$T/bin/$1"
    chmod +x "$T/bin/$1"
}

# ─── fakes ──────────────────────────────────────────────────────────────────
# pacman: installed packages are lines in $T/installed.
stub pacman '
state="$LXTEST_DIR/installed"
touch "$state"
case "$1" in
    -T)
        shift
        rc=0
        for p; do grep -qx -- "$p" "$state" || { echo "$p"; rc=127; }; done
        exit $rc ;;
    -S*)
        echo "pacman $*" >>"$LXTEST_DIR/pacman.log"
        [ "${LXTEST_PACMAN_FAIL:-}" = 1 ] && exit 1
        shift
        for p; do case "$p" in -*) ;; *) echo "$p" >>"$state" ;; esac; done ;;
esac'
stub sudo 'echo "sudo $*" >>"$LXTEST_DIR/sudo.log"; exec "$@"'
stub hyprland 'echo "Hyprland ${LXTEST_HYPR_VERSION:-0.56.2} built from branch v0.56.2 at commit efb5099 clean"'
stub fc-list '[ "${LXTEST_NOFONT:-}" = 1 ] || echo "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf: JetBrainsMono Nerd Font:style=Regular"'
stub id 'case "$1" in -u) echo "${LXTEST_UID:-1000}" ;; -un) echo tester ;; esac'
stub git '
echo "git $*" >>"$LXTEST_DIR/git.log"
for last; do :; done
[ "$1" = clone ] && mkdir -p "$last/.git"
exit 0'
stub curl 'while [ $# -gt 0 ]; do if [ "$1" = -o ]; then printf x >"$2"; shift; fi; shift; done'
stub setsid 'exit 0'

list_names() { sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'; }
repo_pkgs() { list_names "$REPO/packages/repo.txt"; }
opt_pkgs() { list_names "$REPO/packages/optional.txt"; }
mark_installed() { for p; do echo "$p" >>"$T/installed"; done; }
reset_logs() { rm -f "$T/pacman.log" "$T/sudo.log" "$T/git.log"; }
fresh_home() {
    rm -rf "$HOME/.config" "$HOME/.local" "$HOME/.cache" "$HOME/Pictures"
    rm -f "$T/installed"
    reset_logs
}
snapshot() { find "$HOME/.config" "$HOME/.local" -type f -exec cksum {} + 2>/dev/null | sort; }
# inst ANSWERS [ARGS...]: run install.sh with ANSWERS (printf %b) on stdin.
inst() {
    answers=$1
    shift
    out=$(printf '%b' "$answers" | "$SH" "$INSTALL" "$@" 2>&1)
    rc=$?
}
show() { printf '%s\n' "$out" | sed 's/^/        | /'; }

echo "running install.sh with: $SH"

# ─── options ────────────────────────────────────────────────────────────────
echo "[options]"
inst "" --help
check "--help exits 0" test "$rc" -eq 0
check "--help shows usage" has "$out" "usage: sh install.sh"
inst "" --bogus
check "unknown option exits 2" test "$rc" -eq 2
check "no seed file name contains whitespace (install.sh splits on it)" \
    sh -c '! (cd "$1/seeds" && find . -type f | grep -q "[[:space:]]")' _ "$REPO"

# ─── checks ─────────────────────────────────────────────────────────────────
echo "[checks]"
fresh_home
export LXTEST_UID=0
inst "" --yes
unset LXTEST_UID
check "root: refuses" test "$rc" -ne 0
check "root: says why" has "$out" "don't run this as root"
check "root: changed nothing" test ! -e "$HOME/.config"
check "stopping early names the step" has "$out" 'stopped during "Checks"'

cp -r "$COPY" "$T/elsewhere"
out=$("$SH" "$T/elsewhere/install.sh" --yes 2>&1)
rc=$?
check "wrong location: refuses" test "$rc" -ne 0
check "wrong location: says where it has to be" has "$out" "has to be at ~/dotfiles/lynx"
check "wrong location: warns a copy already exists there" has "$out" "is a different copy"
check "wrong location: changed nothing" test ! -e "$HOME/.config"
rm -rf "$T/elsewhere"

cp "$COPY/config/hypr/env.lua" "$T/env.lua.orig"
printf 'x = 1\r\n' >>"$COPY/config/hypr/env.lua"
inst "" --yes
check "CRLF: refuses" test "$rc" -ne 0
check "CRLF: names the file" has "$out" "config/hypr/env.lua"
check "CRLF: changed nothing" test ! -e "$HOME/.config"
cp "$T/env.lua.orig" "$COPY/config/hypr/env.lua"

fresh_home
cp "$COPY/packages/repo.txt" "$T/repo.txt.orig"
printf 'waybar *\n' >>"$COPY/packages/repo.txt"
inst "" --yes
check "not a package name: refuses" test "$rc" -ne 0
check "not a package name: says which" has "$out" "isn't a package name: *"
check "not a package name: pacman never ran" test ! -e "$T/pacman.log"
cp "$T/repo.txt.orig" "$COPY/packages/repo.txt"

# ─── dry run ────────────────────────────────────────────────────────────────
echo "[dry run]"
fresh_home
inst "" --dry-run
check "exits 0" test "$rc" -eq 0
check "shows the pacman command" has "$out" "sudo pacman -Syu --needed hyprland"
check "shows the config copies" has "$out" "cp ~/dotfiles/lynx/seeds/hypr/hyprland.lua ~/.config/hypr/hyprland.lua"
check "ran no pacman install" test ! -e "$T/pacman.log"
check "ran no sudo" test ! -e "$T/sudo.log"
check "created no ~/.config" test ! -e "$HOME/.config"
check "created no ~/.local/bin/lx" test ! -e "$HOME/.local/bin/lx"
check "created no ~/.cache/lynx" test ! -e "$HOME/.cache/lynx"
check "says nothing was changed" has "$out" "nothing was changed"

# ─── fresh install ──────────────────────────────────────────────────────────
echo "[fresh install, --yes]"
fresh_home
inst "" --yes
check "exits 0" test "$rc" -eq 0 || show
check "one pacman -Syu for everything" test "$(grep -c 'pacman -Syu --needed' "$T/pacman.log")" -eq 1
check "through sudo" grep -q "sudo pacman -Syu --needed" "$T/sudo.log"
check "installs every package in repo.txt" sh -c '
    for p in $(sed "s/#.*//" "$1"); do grep -qw -- "$p" "$2" || exit 1; done' _ "$REPO/packages/repo.txt" "$T/pacman.log"
check "optional packages default to no" sh -c '! grep -qw satty "$1"' _ "$T/pacman.log"
check "every seed copied, byte for byte" sh -c '
    cd "$1/seeds" && for f in $(find . -type f); do cmp -s "$f" "$2/$f" || exit 1; done' _ "$COPY" "$HOME/.config"
check "~/.local/bin/lx is executable" test -x "$HOME/.local/bin/lx"
lxout=$(sh "$HOME/.local/bin/lx" 2>&1)
check "~/.local/bin/lx runs the repo's lx" has "$lxout" "usage: lx"
check "palettes are in ~/.cache/lynx" test -s "$HOME/.cache/lynx/colors.css"
check "no wallpaper download by default" test ! -e "$T/git.log"
check "ends by saying how to start" has "$out" "start-hyprland"
check "no warnings on a clean install" lacks "$out" "Needs your attention"

# ─── re-run ─────────────────────────────────────────────────────────────────
echo "[run again]"
before=$(snapshot)
reset_logs
inst "" --yes
check "exits 0" test "$rc" -eq 0
check "no pacman when nothing is missing" test ! -e "$T/pacman.log"
check "changed nothing" test "$(snapshot)" = "$before"
check "reports LYNX's versions as unchanged" has "$out" "~/.config/hypr/hyprland.lua (LYNX's version, unchanged)"

# ─── your files ─────────────────────────────────────────────────────────────
echo "[your files]"
printf '\n#clock { color: red; }\n' >>"$HOME/.config/waybar/style.css"
before=$(snapshot)
inst "" --yes
check "edited config: left exactly as is" test "$(snapshot)" = "$before"
check "edited config: reported as yours" has "$out" "~/.config/waybar/style.css (yours"

printf 'configuration { }\n' >"$HOME/.config/rofi/config.rasi"
inst "" --yes
check "unrelated file + --yes: left alone" grep -qx 'configuration { }' "$HOME/.config/rofi/config.rasi"
check "unrelated file + --yes: listed at the end" sh -c \
    'printf "%s" "$1" | sed -n "/Needs your attention/,\$p" | grep -q "rofi/config.rasi"' _ "$out"

mark_installed $(opt_pkgs) # from here, the only questions are the rename and the wallpapers
inst "y\nn\n"
check "unrelated file + yes: yours renamed, not deleted" grep -qx 'configuration { }' "$HOME/.config/rofi/config.rasi.pre-lynx"
check "unrelated file + yes: LYNX's copied in" cmp -s "$REPO/seeds/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

printf 'configuration { }\n' >"$HOME/.config/rofi/config.rasi"
inst "maybe\ny\nn\n"
check "an unclear answer is asked again" has "$out" "Please answer y or n."
check "a second rename keeps the first backup" test -f "$HOME/.config/rofi/config.rasi.pre-lynx"
check "a second rename gets its own name" grep -qx 'configuration { }' "$HOME/.config/rofi/config.rasi.pre-lynx.2"

if ln -s "$T/nowhere" "$T/linktest" 2>/dev/null && [ -L "$T/linktest" ]; then
    rm -f "$HOME/.config/kitty/kitty.conf"
    ln -s "$T/nowhere/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    inst "" --yes
    check "symlinked config: left alone" test -L "$HOME/.config/kitty/kitty.conf"
    check "symlinked config: nothing written through it" test ! -e "$T/nowhere/kitty.conf"
else
    echo "  SKIP  symlinked config (ln -s makes copies on this system)"
fi

echo "# old" >"$HOME/.config/hypr/hyprland.conf"
inst "" --yes
check "old hyprland.conf: explains hyprland.lua wins" has "$out" "hyprland.conf is still there"
check "old hyprland.conf: not touched" grep -qx '# old' "$HOME/.config/hypr/hyprland.conf"

printf '#!/bin/sh\necho mine\n' >"$HOME/.local/bin/lx"
inst "" --yes
check "someone else's ~/.local/bin/lx: left alone" grep -q mine "$HOME/.local/bin/lx"

# ─── packages ───────────────────────────────────────────────────────────────
echo "[packages]"
fresh_home
mark_installed $(repo_pkgs) xdg-user-dirs fprintd
inst "y\ny\nn\n" # satty? yes. Install now? yes. Wallpapers? no.
check "a picked optional package is installed" grep -qw satty "$T/pacman.log"
check "also with -Syu (no partial upgrade)" grep -q "pacman -Syu --needed satty" "$T/pacman.log"
check "the question shows what it's for" has "$out" "Optional: satty, an Edit button"

fresh_home
inst "n\nn\nn\nn\nn\n" # three optional: no. Install now? no. Wallpapers? no.
check "declined: nothing installed" test ! -e "$T/pacman.log"
check "declined: still finishes" test "$rc" -eq 0
check "declined: listed at the end" has "$out" "skipped installing"
check "declined: configs still set up" test -f "$HOME/.config/hypr/hyprland.lua"

fresh_home
export LXTEST_PACMAN_FAIL=1
inst "" --yes
unset LXTEST_PACMAN_FAIL
check "pacman fails: carries on" test -f "$HOME/.config/hypr/hyprland.lua"
check "pacman fails: warns" has "$out" "pacman didn't finish"
check "pacman fails: lists what's still missing" has "$out" "still not installed: hyprland"

if PATH=/usr/bin:/bin command -v sudo >/dev/null 2>&1; then
    echo "  SKIP  no sudo (this system has a real sudo, and hiding the fake one would call it)"
else
    fresh_home
    mv "$T/bin/sudo" "$T/sudo.off"
    export PATH="$T/bin:/usr/bin:/bin"
    inst "" --yes
    export PATH="$BASE_PATH:$HOME/.local/bin"
    mv "$T/sudo.off" "$T/bin/sudo"
    check "no sudo: stops" test "$rc" -ne 0
    check "no sudo: says how to get it" has "$out" "pacman -S sudo"
fi

# ─── final checks ───────────────────────────────────────────────────────────
echo "[final checks]"
fresh_home
mark_installed $(repo_pkgs) $(opt_pkgs)
inst "" --yes
check "current Hyprland: ok" has "$out" "Hyprland 0.56.2 (LYNX was checked against 0.56.2)"
check "on PATH: ok" has "$out" "~/.local/bin is on your PATH"

export LXTEST_HYPR_VERSION=0.55.1
inst "" --yes
unset LXTEST_HYPR_VERSION
check "older Hyprland: warns" has "$out" "Hyprland 0.55.1 is older than 0.56.2"

export LXTEST_HYPR_VERSION=garbage
inst "" --yes
unset LXTEST_HYPR_VERSION
check "unreadable Hyprland version: warns instead of crashing" has "$out" "couldn't read Hyprland's version"

export LXTEST_NOFONT=1
inst "" --yes
unset LXTEST_NOFONT
check "no Nerd Font: warns" has "$out" "JetBrainsMono Nerd Font isn't found"

export PATH="$BASE_PATH"
inst "" --yes
export PATH="$BASE_PATH:$HOME/.local/bin"
check "not on PATH: says what to add" has "$out" 'export PATH="$HOME/.local/bin:$PATH"'

# ─── wallpapers ─────────────────────────────────────────────────────────────
echo "[wallpapers]"
fresh_home
mark_installed $(repo_pkgs) $(opt_pkgs)
inst "y\n"
check "yes: downloads the ML4W collection" grep -q "clone --depth=1 https://github.com/mylinuxforwork/wallpaper.git" "$T/git.log"
check "into ~/Pictures/Wallpapers" test -d "$HOME/Pictures/Wallpapers/ml4w/.git"
reset_logs
inst "" --yes
check "already downloaded: not asked again" lacks "$out" "Download them now?"
check "already downloaded: nothing fetched" test ! -e "$T/git.log"

echo
echo "$pass passed, $fail failed ($SH)"
[ "$fail" -eq 0 ]
