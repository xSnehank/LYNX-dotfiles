#!/bin/sh
# LYNX :: install.sh
#
# Sets LYNX up for your user on Arch Linux. Run it from the repo, as yourself
# (not root):
#
#   sh ~/dotfiles/lynx/install.sh             asks before each step
#   sh ~/dotfiles/lynx/install.sh --dry-run   shows every step, changes nothing
#   sh ~/dotfiles/lynx/install.sh --yes       no questions: takes every default
#
# The steps, in order:
#   1. Checks        can this work here at all? Changes nothing.
#   2. Packages      packages/repo.txt, plus any of packages/optional.txt you pick
#   3. Configs       copies each file in seeds/ into ~/.config, only where you
#                    don't have that file yet
#   4. lx            a small `lx` command in ~/.local/bin
#   5. Palettes      fallback colors in ~/.cache/lynx
#   6. Wallpapers    offers to download the Caelestia + ML4W collections
#   7. Final checks  what's still missing, and what to do next
#
# What it promises:
#   - Safe to run again at any time, for example after `git pull`: every step
#     skips what's already done.
#   - Never overwrites or deletes a file of yours. It moves one aside only when
#     you answer yes to that exact question, and then it's renamed, not deleted.
#   - sudo is used for one command only: pacman. pacman shows its own list and
#     asks you to confirm, even with --yes.
#   - Doesn't enable services, edit your shell profile, or write anywhere except
#     ~/.config, ~/.local/bin/lx, ~/.cache/lynx and (only if you say yes) the
#     wallpaper folder.
#
# Plain POSIX sh, like bin/lx, and for the same reason: `sh install.sh` works
# even if the executable bit got lost along the way.

set -eu
unset CDPATH # so `cd` never prints anything or lands somewhere unexpected

if [ -z "${HOME:-}" ]; then
    echo "install.sh: HOME isn't set, so there's no way to know where your configs go." >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
usage: sh install.sh [--dry-run] [--yes]

  --dry-run   show every step and command, change nothing
  --yes       ask no questions; take each question's default answer
              (pacman still asks before it installs anything)
  --help      this text

Safe to run again at any time: every step skips what's already done.
USAGE
}

DRY_RUN=0
ASSUME_DEFAULTS=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -y | --yes) ASSUME_DEFAULTS=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'install.sh: unknown option: %s\n\n' "$arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# ─── Paths ─────────────────────────────────────────────────────────────────
LYNX_DIR=$(cd "$(dirname "$0")" && pwd -P) # the repo this script is in
HOME_LYNX="$HOME/dotfiles/lynx"              # where every LYNX config expects it
CONFIG_HOME="$HOME/.config"                  # deliberately fixed: see step 1
LX_COMMAND="$HOME/.local/bin/lx"
WALL_DIR="${LYNX_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}" # same as bin/lx

# ─── Output ────────────────────────────────────────────────────────────────
# Colors only when writing to a terminal, so a saved copy stays readable.
if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
    BOLD=$(printf '\033[1m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    RED=$(printf '\033[31m')
    RESET=$(printf '\033[0m')
else
    BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi

WARNINGS="" # every warning, repeated at the end so none scroll out of sight
STEP=""     # the step in progress, named if install.sh stops early
FINISHED=0

step() {
    STEP=$2
    printf '\n%s[%s] %s%s\n' "$BOLD" "$1" "$2" "$RESET"
}

ok() {
    printf '  %sok%s     %s\n' "$GREEN" "$RESET" "$*"
}

note() {
    printf '         %s\n' "$*"
}

warn() {
    printf '  %swarn%s   %s\n' "$YELLOW" "$RESET" "$*"
    WARNINGS="$WARNINGS
  - $*"
}

die() {
    printf '\n%sinstall.sh: %s%s\n' "$RED" "$*" "$RESET" >&2
    exit 1
}

on_exit() {
    status=$?
    if [ "$FINISHED" = 0 ] && [ -n "$STEP" ]; then
        printf '\ninstall.sh stopped during "%s". Steps before it are done; nothing after it ran.\n' "$STEP" >&2
        printf 'Once the problem above is fixed, run it again: it skips what is already done.\n' >&2
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 130' INT TERM

# $HOME/x -> ~/x, for messages.
tilde() {
    case "$1" in
        "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Show a command, then run it. With --dry-run, only show it.
run() {
    printf '  $     '
    for word in "$@"; do
        printf ' %s' "$(tilde "$word")"
    done
    printf '\n'
    [ "$DRY_RUN" = 1 ] || "$@"
}

# ask QUESTION DEFAULT: succeeds for yes. DEFAULT is y or n. It's the answer
# for Enter on its own, for --yes and for --dry-run.
ask() {
    if [ "$2" = y ]; then choices="[Y/n]"; else choices="[y/N]"; fi
    if [ "$DRY_RUN" = 1 ] || [ "$ASSUME_DEFAULTS" = 1 ]; then
        if [ "$2" = y ]; then answer=yes; else answer=no; fi
        printf '  ?      %s %s %s (default)\n' "$1" "$choices" "$answer"
        [ "$2" = y ]
        return
    fi
    while :; do
        printf '  ?      %s %s ' "$1" "$choices"
        # No input left at all counts as pressing Enter: take the default.
        if ! read -r reply; then
            reply=""
            printf '\n'
        fi
        case "$reply" in
            "")
                [ "$2" = y ]
                return
                ;;
            [yY] | [yY][eE][sS]) return 0 ;;
            [nN] | [nN][oO]) return 1 ;;
        esac
        note "Please answer y or n."
    done
}

printf '%sLYNX installer%s\n' "$BOLD" "$RESET"
if [ "$DRY_RUN" = 1 ]; then
    printf 'Dry run: commands are shown after $ but not run, and questions take their default.\n'
fi

# ─── 1. Checks ─────────────────────────────────────────────────────────────
step 1/7 "Checks"

if [ "$(id -u)" -eq 0 ]; then
    die "don't run this as root or with sudo: everything it sets up belongs to your own user.
Run it as yourself:  sh $LYNX_DIR/install.sh
It asks for your password when pacman needs it."
fi
ok "running as $(id -un), not root"

if ! command -v pacman >/dev/null 2>&1; then
    die "pacman isn't here. LYNX is written for Arch Linux and installs its packages with pacman."
fi
ok "pacman is here"

# Every LYNX config names ~/dotfiles/lynx directly: Waybar's buttons, the idle
# daemon's lock command, the style imports. Some of those formats can't read
# a variable, so the location can't be made configurable in one place.
home_lynx=$(cd "$HOME_LYNX" 2>/dev/null && pwd -P || true)
if [ "$LYNX_DIR" != "$home_lynx" ]; then
    also=""
    if [ -n "$home_lynx" ]; then
        also="
(~/dotfiles/lynx already exists and is a different copy: decide which one to keep first.)"
    fi
    die "this copy of LYNX is at $LYNX_DIR, but it has to be at ~/dotfiles/lynx.
LYNX's configs name that path directly (the bar, the idle daemon and the style
imports all point there), so from anywhere else parts of it would quietly do
nothing. Move it there, then run install.sh again:
  mkdir -p ~/dotfiles && mv '$LYNX_DIR' ~/dotfiles/lynx$also"
fi
ok "the repo is at ~/dotfiles/lynx"

for file in bin/lx packages/repo.txt packages/optional.txt seeds/hypr/hyprland.lua; do
    if [ ! -f "$LYNX_DIR/$file" ]; then
        die "$file is missing from the repo. Is this a complete copy of LYNX?"
    fi
done

# A Windows line ending in a shell script or config fails silently: "bad
# interpreter", or a config line that quietly does nothing. The repo's
# .gitattributes prevents that for git clones. A copy made some other way (a
# zip file, a USB stick, a Windows editor) can still bring them in.
# (-U changes nothing on Linux. It only stops Windows builds of grep from
# hiding the very character this looks for.)
cr=$(printf '\r')
crlf_files=$(grep -rlIU "$cr" "$LYNX_DIR/bin" "$LYNX_DIR/config" "$LYNX_DIR/seeds" \
    "$LYNX_DIR/templates" "$LYNX_DIR/packages" 2>/dev/null || true)
if [ -n "$crlf_files" ]; then
    die "these files have Windows line endings, which break shell scripts and configs:
$(printf '%s\n' "$crlf_files" | sed "s|^$LYNX_DIR/|  |" | head -n 10)
If this copy came from git, delete it and clone again. Otherwise fix each file with:
  sed -i 's/\r\$//' FILE"
fi
ok "no Windows line endings"

# The seeds are written for ~/.config: swaync's and Waybar's style imports find
# LYNX with paths relative to it.
case "${XDG_CONFIG_HOME:-$HOME/.config}" in
    "$HOME/.config" | "$HOME/.config/") ;;
    *) warn "XDG_CONFIG_HOME is set to $XDG_CONFIG_HOME. LYNX's configs are written for ~/.config and go there anyway, so programs that follow XDG_CONFIG_HOME won't see them." ;;
esac

# ─── 2. Packages ───────────────────────────────────────────────────────────
step 2/7 "Packages"

# The package names in a list file, one per line: comments and blank lines
# removed.
package_names() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$' || true
}

# Names are passed to pacman unquoted below, so a line that isn't a plain
# package name (spaces, wildcards, a stray word) must stop the install here.
for list in repo optional; do
    bad=$(package_names "$LYNX_DIR/packages/$list.txt" | grep -v '^[a-z0-9@._+-]*$' || true)
    if [ -n "$bad" ]; then
        die "packages/$list.txt contains something that isn't a package name: $bad"
    fi
done

REPO_PACKAGES=$(package_names "$LYNX_DIR/packages/repo.txt")
total=$(printf '%s\n' "$REPO_PACKAGES" | wc -l)

# pacman -T prints each package that isn't installed. A package also counts as
# installed when something installed "provides" it.
missing=$(pacman -T $REPO_PACKAGES || true)
if [ -z "$missing" ]; then
    ok "all $total packages in packages/repo.txt are installed"
else
    note "$(printf '%s\n' $missing | wc -l) of the $total packages in packages/repo.txt aren't installed yet."
fi

chosen=""
for name in $(package_names "$LYNX_DIR/packages/optional.txt"); do
    if pacman -T "$name" >/dev/null 2>&1; then
        ok "$name (optional) is installed"
        continue
    fi
    what=$(sed -n "s/^$name[[:space:]]*#[[:space:]]*//p" "$LYNX_DIR/packages/optional.txt")
    note "Optional: $name, $what"
    if ask "Include $name?" n; then
        chosen="$chosen $name"
    fi
done

to_install=$(echo $missing $chosen)
if [ -n "$to_install" ]; then
    note "To install:"
    printf '%s\n' "$to_install" | fold -s -w 66 | sed 's/^/           /'
    note "pacman -Syu also brings the rest of the system up to date. Arch needs"
    note "that: installing new packages onto out-of-date ones (a \"partial"
    note "upgrade\") can leave programs unable to start. pacman lists everything"
    note "and asks before it changes anything."
    if ask "Install now?" y; then
        if ! command -v sudo >/dev/null 2>&1; then
            if [ "$DRY_RUN" = 1 ]; then
                warn "sudo isn't installed, so a real run would stop here"
            else
                die "sudo isn't installed. As root (log in as root, or use su), install it:
  pacman -S sudo
let the wheel group use it: run  EDITOR=nano visudo  and remove the # in front of
  %wheel ALL=(ALL:ALL) ALL
and make sure you're in that group:  usermod -aG wheel $(id -un)
Then log in again and run install.sh again."
            fi
        fi
        if run sudo pacman -Syu --needed $to_install; then
            [ "$DRY_RUN" = 1 ] || ok "packages installed"
        else
            warn "pacman didn't finish (its message is above), so some packages are missing. Run install.sh again once that's sorted out."
        fi
    else
        warn "skipped installing: $to_install"
    fi
fi

# ─── 3. Configs ────────────────────────────────────────────────────────────
step 3/7 "Configs in ~/.config"
note "Each file is copied only if you don't have it yet. Once it's there, it's"
note "yours: install.sh never changes it again."

same_file() {
    [ "$(cksum <"$1")" = "$(cksum <"$2")" ]
}

# The first of NAME, NAME.2, NAME.3, ... that doesn't exist yet.
unused_name() {
    candidate=$1
    n=1
    while [ -e "$candidate" ] || [ -L "$candidate" ]; do
        n=$((n + 1))
        candidate="$1.$n"
    done
    printf '%s' "$candidate"
}

created=0
# A `for` loop rather than `while read`: the question inside must read your
# answer from the terminal, and `while read` would feed it the file list
# instead. Seed file names contain no spaces, so splitting on them is safe.
for rel in $(cd "$LYNX_DIR/seeds" && find . -type f | sed 's|^\./||' | sort); do
    seed="$LYNX_DIR/seeds/$rel"
    dest="$CONFIG_HOME/$rel"
    shown="~/.config/$rel"

    if [ -L "$dest" ]; then
        # Most likely managed by another dotfiles tool (stow, chezmoi, ...).
        warn "$shown is a symlink, so something else manages it; left alone"
    elif [ ! -e "$dest" ]; then
        [ -d "$(dirname "$dest")" ] || run mkdir -p "$(dirname "$dest")"
        run cp "$seed" "$dest"
        created=$((created + 1))
    elif [ ! -f "$dest" ]; then
        warn "$shown exists but isn't a regular file; left alone"
    elif same_file "$seed" "$dest"; then
        ok "$shown (LYNX's version, unchanged)"
    elif grep -q -e 'LYNX' -e 'dotfiles/lynx' -e '\.cache/lynx' "$dest"; then
        ok "$shown (yours, with your changes; left as is)"
    else
        backup=$(unused_name "$dest.pre-lynx")
        note "$shown already exists and has nothing to do with LYNX,"
        note "so that program won't use LYNX while it's there."
        if ask "Rename yours to $(tilde "$backup") and use LYNX's?" n; then
            run mv "$dest" "$backup"
            run cp "$seed" "$dest"
            created=$((created + 1))
        else
            warn "$shown isn't LYNX's, so that program won't use LYNX. To switch later: mv $shown $(tilde "$backup") && cp ~/dotfiles/lynx/seeds/$rel $shown"
        fi
    fi
done

# Checked in Hyprland 0.56.2 (src/config/supplementary/jeremy/Jeremy.cpp): it
# looks for hyprland.lua first and only falls back to hyprland.conf without it.
if [ -f "$CONFIG_HOME/hypr/hyprland.conf" ]; then
    note "~/.config/hypr/hyprland.conf is still there. Hyprland ignores it from now"
    note "on, because it loads hyprland.lua whenever that exists. Nothing needs deleting."
fi

# ─── 4. The lx command ─────────────────────────────────────────────────────
step 4/7 "The lx command"

# A tiny script rather than a symlink: it keeps working if bin/lx loses its
# executable bit, and LYNX doesn't use symlinks anywhere else either.
LX_WRAPPER='#!/bin/sh
# Created by LYNX install.sh. Runs bin/lx from your LYNX repo, so it is always
# the current version. Safe to delete; install.sh puts it back.
exec sh "$HOME/dotfiles/lynx/bin/lx" "$@"'

if [ -L "$LX_COMMAND" ] || { [ -e "$LX_COMMAND" ] && ! grep -q 'Created by LYNX install.sh' "$LX_COMMAND" 2>/dev/null; }; then
    warn "~/.local/bin/lx already exists and isn't LYNX's; left alone. LYNX doesn't need it: its keybinds and bar call ~/dotfiles/lynx/bin/lx directly."
elif [ -f "$LX_COMMAND" ] && [ "$(cat "$LX_COMMAND")" = "$LX_WRAPPER" ]; then
    ok "~/.local/bin/lx is in place"
else
    printf '  $      write ~/.local/bin/lx, which runs: sh ~/dotfiles/lynx/bin/lx ...\n'
    if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$(dirname "$LX_COMMAND")"
        printf '%s\n' "$LX_WRAPPER" >"$LX_COMMAND.tmp"
        chmod +x "$LX_COMMAND.tmp"
        mv -f "$LX_COMMAND.tmp" "$LX_COMMAND"
    fi
fi

case ":$PATH:" in
    *":$HOME/.local/bin:"* | *":$HOME/.local/bin/:"*)
        ok "~/.local/bin is on your PATH, so typing lx in a terminal works"
        ;;
    *)
        warn "~/.local/bin isn't on your PATH, so typing lx in a terminal won't find it (LYNX itself doesn't need it). To fix, add this line to ~/.bashrc (or ~/.zshrc), then open a new terminal:  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

# ─── 5. Color palettes ─────────────────────────────────────────────────────
step 5/7 "Color palettes"

# Only fills in missing files, never overwrites. Hyprland runs the same command
# at every login; running it now also proves bin/lx works on this system.
run sh "$LYNX_DIR/bin/lx" theme ensure
[ "$DRY_RUN" = 1 ] || ok "~/.cache/lynx has LYNX's fallback colors; picking a wallpaper (SUPER + W) recolors everything"

# ─── 6. Wallpapers ─────────────────────────────────────────────────────────
step 6/7 "Wallpapers"

if [ -d "$WALL_DIR/ml4w/.git" ]; then
    ok "the Caelestia + ML4W wallpapers are in $(tilde "$WALL_DIR") (update them: lx wallpaper fetch)"
else
    note "LYNX comes with one wallpaper of its own. The Caelestia and ML4W"
    note "collections are about 840 MB from GitHub, into $(tilde "$WALL_DIR")."
    note "You can also do this any time later:  lx wallpaper fetch"
    if ask "Download them now?" n; then
        if ! run sh "$LYNX_DIR/bin/lx" wallpaper fetch; then
            warn "not every wallpaper downloaded (see above). Retry any time: lx wallpaper fetch"
        fi
    fi
fi

# ─── 7. Final checks ───────────────────────────────────────────────────────
step 7/7 "Final checks"

still_missing=$(pacman -T $REPO_PACKAGES || true)
if [ -z "$still_missing" ]; then
    ok "every package in packages/repo.txt is installed"
elif [ "$DRY_RUN" = 1 ]; then
    note "$(printf '%s\n' $still_missing | wc -l) packages aren't installed yet (a real run installs them)"
else
    warn "still not installed: $(echo $still_missing)"
fi

if command -v hyprland >/dev/null 2>&1; then
    # First line looks like: Hyprland 0.56.2 built from branch v0.56.2 at commit ...
    version=$(hyprland --version 2>/dev/null | awk 'NR == 1 { print $2 }')
    major=${version%%.*}
    minor=${version#*.}
    minor=${minor%%.*}
    case "$major.$minor" in
        *[!0-9.]* | .* | *.)
            warn "couldn't read Hyprland's version from: hyprland --version"
            ;;
        *)
            if [ "$major" -eq 0 ] && [ "$minor" -lt 56 ]; then
                warn "Hyprland $version is older than 0.56.2, the version LYNX's Lua config was checked against. Update with: sudo pacman -Syu"
            else
                ok "Hyprland $version (LYNX was checked against 0.56.2)"
            fi
            ;;
    esac
fi

case " $(echo $still_missing) " in
    *" ttf-jetbrains-mono-nerd "*) ;; # already reported as a missing package
    *)
        if fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd'; then
            ok "JetBrainsMono Nerd Font is installed (icons in the bar and launcher)"
        else
            warn "JetBrainsMono Nerd Font isn't found, so icons in the bar and launcher show as empty boxes. Check with: fc-list | grep -i 'JetBrainsMono Nerd'"
        fi
        ;;
esac

# ─── Summary ───────────────────────────────────────────────────────────────
FINISHED=1
printf '\n%sDone.%s\n' "$BOLD" "$RESET"
if [ "$DRY_RUN" = 1 ]; then
    printf 'This was a dry run: nothing was changed. Run it without --dry-run to do the steps above.\n'
fi
if [ -n "$WARNINGS" ]; then
    printf '\n%sNeeds your attention:%s%s\n' "$YELLOW" "$RESET" "$WARNINGS"
fi

cat <<'NEXT'

Next:
  1. If Hyprland is running, exit it. (Already running LYNX, and nothing new
     was copied into ~/.config? Then  hyprctl reload  is enough.)
  2. Log in on a TTY and start Hyprland with:  start-hyprland
     If Hyprland ever crashes, start-hyprland starts it again in safe mode (a
     minimal recovery config, still locked if the screen was locked) instead
     of dropping you back to the TTY. Plain `Hyprland` works too, but shows a
     warning banner about the missing watchdog.
  3. SUPER + Return opens a terminal, SUPER + Space the app launcher.
     Every keybind: ~/dotfiles/lynx/docs/keybinds.md
  4. Check that the config loaded cleanly:  hyprctl configerrors
NEXT
