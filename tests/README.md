# Tests

Run these after changing anything in `config/`, `seeds/`, `templates/`,
`bin/lx` or `install.sh`. They are how LYNX was checked before it ever ran on
real hardware.

**They never touch your system.** `HOME` is redirected to a temp folder, and
every program that would change something — pacman, sudo, hyprctl, pkill, git,
wl-copy, systemctl — is replaced by a fake that only records what it was asked
to do. What's being tested is LYNX's own logic, not the programs it calls.

| Command | What it checks |
|---|---|
| `python3 tests/check_lynx.py` | The repo is internally consistent: Lua parses, no keybind is bound twice, every color name a stylesheet uses is defined, the four fallback palettes match, rasi/hyprlang/JSON files are well-formed, the matugen templates render into files `lx` accepts, and no file has Windows line endings. |
| `sh tests/smoke_lx.sh` | `bin/lx` does the right thing: what it writes, what it refuses, how it escapes text, how it falls back when a program is missing. |
| `sh tests/smoke_install.sh` | `install.sh` installs, seeds and re-runs safely, and never overwrites a config of yours. Pass `dash` to run the installer under dash instead of sh: `sh tests/smoke_install.sh dash`. |

All three, one after another:

```bash
python3 tests/check_lynx.py && sh tests/smoke_lx.sh && sh tests/smoke_install.sh
```

Expect `ALL CHECKS PASSED` from the first and `N passed, 0 failed` from the
other two. A `SKIP` line is a test that can't run here, not a failure.

## What they need

- **python3** for `check_lynx.py` and for the fake matugen the other tests use.
- **luaparser**, optional: without it, the Lua syntax check skips itself.
  ```bash
  pip install --user luaparser
  ```
- **swaync installed**, optional: the swaync config is checked against
  `/etc/xdg/swaync/configSchema.json`, which that package ships. Without it,
  that one check skips itself. Point `LYNX_SWAYNC_SCHEMA` at a copy of the
  schema to check anyway.

`render_templates.py` is not a test. It's a stand-in for matugen — it
implements just the part of matugen's template language LYNX uses, so the
templates can be checked without generating real colors. Both other scripts
use it.

## Fakes, not mocks of your desktop

The scripts were written on Windows under Git Bash and run there too, which is
why they avoid anything Linux-specific. Two tests skip themselves on a normal
Arch machine, and say so when they do:

- the symlink test, where `ln -s` makes copies instead of links (Git Bash)
- the "sudo isn't installed" test, when a real `sudo` exists — hiding the fake
  one would hand `sudo pacman` to the real thing
