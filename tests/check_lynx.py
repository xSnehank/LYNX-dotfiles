"""Repo-wide sanity checks for LYNX. Re-run after any change.

  [1] every Lua file parses (luaparser)
  [2] no key combination is bound twice in keybinds.lua
  [3] every palette name a stylesheet, rofi theme or lock screen uses is defined
  [4] the Waybar, rofi, swaync and hyprlock fallback palettes are identical
  [5] rasi files: braces balance, and relative imports point at real files
  [6] swaync config: valid JSON once // comments are removed, known options, valid values
  [7] hyprlang configs (hyprlock, hypridle, hyprpaper): braces balance, LYNX
      `source =` targets exist, and no shell "$(" (hyprlang treats it as math)
  [8] theme: matugen config, templates render with real matugen names, every
      rendered file passes lx's own checks and matches its fallback's names
  [9] no CRLF line endings anywhere in the repo

Run it from anywhere:  python3 tests/check_lynx.py
Checks [1] and [6] skip themselves when luaparser or swaync isn't installed.
"""
import collections
import glob
import json
import os
import re
import sys
import tomllib

SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SP)
import render_templates as rt  # noqa: E402

# The repo is whatever folder this tests/ directory sits in.
REPO = os.path.dirname(SP).replace("\\", "/")

# Check [1] needs the luaparser package. Without it that one check is skipped
# and the rest still run:  pip install --user luaparser
try:
    from luaparser import ast  # noqa: E402
except ImportError:
    ast = None

# Check [6] reads swaync's own schema, which the swaync package installs.
# Point LYNX_SWAYNC_SCHEMA at a copy to check without swaync installed.
SWAYNC_SCHEMA = os.environ.get("LYNX_SWAYNC_SCHEMA", "/etc/xdg/swaync/configSchema.json")
failed = 0


def rel(path):
    return os.path.relpath(path, REPO).replace("\\", "/")


def read(path):
    return open(path, encoding="utf-8").read()


def fail(msg):
    global failed
    failed += 1
    print(f"    FAIL  {msg}")


def strip_block_comments(text):
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def strip_line_comments(text):
    return re.sub(r"(?m)^\s*//.*$", "", text)


def strip_hash_comments(text):
    # hyprlang: '#' starts a comment ('##' is an escaped literal '#').
    return "\n".join(re.split(r"(?<!#)#(?!#)", line, maxsplit=1)[0] for line in text.splitlines())


HEX = r"(#[0-9a-fA-F]{6,8})"


def parse_gtk3(text):
    return dict(re.findall(r"@define-color\s+([A-Za-z0-9_-]+)\s+" + HEX + r"\s*;", text))


def parse_rasi(text):
    return dict(re.findall(r"(?m)^\s*([A-Za-z0-9-]+)\s*:\s*" + HEX + r"\s*;",
                           strip_line_comments(strip_block_comments(text))))


def parse_gtk4(text):
    return dict(re.findall(r"--([A-Za-z0-9_-]+)\s*:\s*" + HEX + r"\s*;", strip_block_comments(text)))


def parse_hyprlock(text):
    return {name: "#%02x%02x%02x" % (int(r), int(g), int(b))
            for name, r, g, b in re.findall(r"(?m)^\s*\$([A-Za-z0-9_]+)\s*=\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*$",
                                            strip_hash_comments(text))}


def parse_kitty(text):
    return dict(re.findall(r"(?m)^([a-z_0-9]+)\s+(#[0-9a-fA-F]{6})\s*$", text))


# [1] ──────────────────────────────────────────────────────────────────────────
print("[1] Lua syntax")
lua_files = sorted(glob.glob(f"{REPO}/config/hypr/*.lua")) + sorted(glob.glob(f"{REPO}/seeds/hypr/*.lua"))
if ast is None:
    print("    SKIP  luaparser isn't installed:  pip install --user luaparser")
    lua_files = []
for f in lua_files:
    try:
        ast.parse(read(f))
        print(f"    OK    {rel(f)}")
    except Exception as e:
        fail(f"{rel(f)}: {str(e).splitlines()[0][:160]}")

# [2] ──────────────────────────────────────────────────────────────────────────
print("[2] duplicate keybinds")
code = "\n".join(line.split("--", 1)[0] for line in read(f"{REPO}/config/hypr/keybinds.lua").splitlines())
keys = []
for m in re.finditer(r'hl\.bind\((mod \.\. )?"([^"]+)"', code):
    combo = (("SUPER" if m.group(1) else "") + m.group(2)).replace(" ", "").upper()
    if not combo.endswith("+"):  # skip the workspace loop's `mod .. " + " .. key` fragments
        keys.append(combo)
if "for i = 1, 10 do" in code:
    for i in range(1, 11):
        keys += [f"SUPER+{i % 10}", f"SUPER+SHIFT+{i % 10}"]
dupes = sorted(k for k, n in collections.Counter(keys).items() if n > 1)
print(f"    {len(keys)} key combos; duplicates: {dupes or 'none'}")
if dupes:
    fail(f"duplicate binds: {dupes}")

# [3] ──────────────────────────────────────────────────────────────────────────
print("[3] palette names used are defined")
gtk3_palette = parse_gtk3(read(f"{REPO}/config/waybar/fallback-colors.css"))
rasi_palette = parse_rasi(read(f"{REPO}/config/rofi/fallback-colors.rasi"))
gtk4_palette = parse_gtk4(read(f"{REPO}/config/swaync/fallback-colors.css"))
lock_palette = parse_hyprlock(read(f"{REPO}/config/hyprlock/fallback-colors.conf"))
kitty_palette = parse_kitty(read(f"{REPO}/config/kitty/fallback-colors.conf"))

for css in (f"{REPO}/config/waybar/style.css", f"{REPO}/seeds/waybar/style.css"):
    used = set(re.findall(r"@([A-Za-z_][\w-]*)", strip_block_comments(read(css)))) - {"import", "define-color"}
    missing = sorted(used - set(gtk3_palette))
    print(f"    {rel(css)}: {len(used)} names used; undefined: {missing or 'none'}")
    if missing:
        fail(f"{rel(css)} uses undefined colors {missing}")

for rasi in sorted(glob.glob(f"{REPO}/config/rofi/*.rasi")) + sorted(glob.glob(f"{REPO}/seeds/rofi/*.rasi")):
    if rasi.endswith("fallback-colors.rasi"):
        continue
    body = strip_line_comments(strip_block_comments(read(rasi)))
    used = set(re.findall(r"@([A-Za-z0-9-]+)", body)) - {"import", "theme", "media"}
    used |= set(re.findall(r"var\(\s*([A-Za-z0-9-]+)", body))
    missing = sorted(used - set(rasi_palette))
    print(f"    {rel(rasi)}: {len(used)} names used; undefined: {missing or 'none'}")
    if missing:
        fail(f"{rel(rasi)} uses undefined colors {missing}")

for css in (f"{REPO}/config/swaync/style.css", f"{REPO}/seeds/swaync/style.css"):
    body = strip_block_comments(read(css))
    used = set(re.findall(r"var\(\s*--([A-Za-z0-9_-]+)", body))
    defined_here = set(re.findall(r"--([A-Za-z0-9_-]+)\s*:", body))
    missing = sorted(used - set(gtk4_palette) - defined_here)
    print(f"    {rel(css)}: {len(used)} variables used; undefined: {missing or 'none'}")
    if missing:
        fail(f"{rel(css)} uses undefined variables {missing}")

HYPRLOCK_RUNTIME = {"USER", "DESC", "TIME", "TIME12", "LAYOUT", "ATTEMPTS", "FAIL",
                    "PAMPROMPT", "PAMFAIL", "FPRINTPROMPT", "FPRINTFAIL", "HOME"}
knobs = set(re.findall(r"(?m)^\s*\$([A-Za-z0-9_]+)\s*=",
                       strip_hash_comments(read(f"{REPO}/config/hyprlock/defaults.conf"))))
lock_files = [f for f in sorted(glob.glob(f"{REPO}/config/hyprlock/*.conf")) if not f.endswith("fallback-colors.conf")]
for conf in lock_files + [f"{REPO}/seeds/hypr/hyprlock.conf"]:
    body = strip_hash_comments(read(conf))
    used = set(re.findall(r"\$([A-Za-z_][A-Za-z0-9_]*)", body))
    missing = sorted(used - set(lock_palette) - knobs - HYPRLOCK_RUNTIME)
    print(f"    {rel(conf)}: {len(used)} variables used; undefined: {missing or 'none'}")
    if missing:
        fail(f"{rel(conf)} uses undefined variables {missing}")

# [4] ──────────────────────────────────────────────────────────────────────────
print("[4] fallback palettes identical (Waybar / rofi / swaync / hyprlock)")
reference = {k: v.lower() for k, v in gtk3_palette.items()}
others = {
    "rofi": {k.replace("-", "_"): v.lower() for k, v in rasi_palette.items()},
    "swaync": {k: v.lower() for k, v in gtk4_palette.items()},
    "hyprlock": lock_palette,
}
bad = False
for label, other in others.items():
    if other != reference:
        bad = True
        fail(f"{label} palette differs from waybar: "
             f"missing={sorted(set(reference) - set(other))} "
             f"extra={sorted(set(other) - set(reference))} "
             f"values={sorted(k for k in set(reference) & set(other) if reference[k] != other[k])}")
if not bad:
    print(f"    {len(reference)} roles, identical in all four")

# [5] ──────────────────────────────────────────────────────────────────────────
print("[5] rasi structure")
for rasi in sorted(glob.glob(f"{REPO}/config/rofi/*.rasi")) + sorted(glob.glob(f"{REPO}/seeds/rofi/*.rasi")):
    body = strip_line_comments(strip_block_comments(read(rasi)))
    no_strings = re.sub(r'"[^"\n]*"', '""', body)
    opens, closes = no_strings.count("{"), no_strings.count("}")
    problems = []
    if opens != closes:
        problems.append(f"braces {{={opens} }}={closes}")
    for optional, target in re.findall(r'(?m)^\s*([@?])import\s+"([^"]+)"', body):
        if target.startswith("~") or target.startswith("/"):
            continue  # points at the user's machine; can't check here
        if optional == "@" and not os.path.exists(os.path.join(os.path.dirname(rasi), target)):
            problems.append(f"missing import target {target}")
    if problems:
        fail(f"{rel(rasi)}: {'; '.join(problems)}")
    else:
        print(f"    OK    {rel(rasi)} ({opens} blocks)")

# [6] ──────────────────────────────────────────────────────────────────────────
print("[6] swaync config")
seed = f"{REPO}/seeds/swaync/config.json"
if os.path.exists(SWAYNC_SCHEMA):
    schema_props = json.load(open(SWAYNC_SCHEMA, encoding="utf-8"))["properties"]
else:
    schema_props = None
    print(f"    SKIP  option names: no schema at {SWAYNC_SCHEMA} (install swaync)")
try:
    cfg = json.loads(strip_line_comments(read(seed)))
    problems = []
    for key, value in cfg.items():
        if schema_props is None:
            break
        if key not in schema_props:
            problems.append(f"unknown option '{key}'")
            continue
        enum = schema_props[key].get("enum")
        if enum and value not in enum:
            problems.append(f"'{key}': {value!r} not one of {enum}")
    for widget in cfg.get("widgets", []):
        if widget not in cfg.get("widget-config", {}):
            problems.append(f"widget '{widget}' has no widget-config entry (uses defaults)")
    if problems:
        fail(f"{rel(seed)}: {'; '.join(problems)}")
    else:
        print(f"    OK    {rel(seed)} ({len(cfg)} options, all in swaync 0.12.6's schema)")
except json.JSONDecodeError as e:
    fail(f"{rel(seed)}: invalid JSON after removing // comments: {e}")

# [7] ──────────────────────────────────────────────────────────────────────────
print("[7] hyprlang configs")
hyprlang_files = (sorted(glob.glob(f"{REPO}/config/hyprlock/*.conf"))
                  + [f"{REPO}/config/hypr/hypridle.conf", f"{REPO}/config/hypr/hyprpaper.conf"]
                  + [f"{REPO}/seeds/hypr/{n}" for n in ("hyprlock.conf", "hypridle.conf", "hyprpaper.conf")])
for conf in hyprlang_files:
    body = strip_hash_comments(read(conf))
    problems = []
    if body.count("{") != body.count("}"):
        problems.append(f"braces {{={body.count('{')} }}={body.count('}')}")
    if "$(" in body:
        problems.append('contains "$(" which hyprlang evaluates as arithmetic')
    for target in re.findall(r"(?m)^\s*source\s*=\s*(\S+)", body):
        if target.startswith("~/dotfiles/lynx/"):
            if not os.path.exists(f"{REPO}/{target[len('~/dotfiles/lynx/'):]}"):
                problems.append(f"source target missing in repo: {target}")
    if problems:
        fail(f"{rel(conf)}: {'; '.join(problems)}")
    else:
        print(f"    OK    {rel(conf)}")

# [8] ──────────────────────────────────────────────────────────────────────────
print("[8] theme templates")
lx_text = read(f"{REPO}/bin/lx")
lx_roles = re.search(r'THEME_ROLES="([^"]+)"', lx_text)
lx_outputs = re.search(r'THEME_OUTPUTS="([^"]+)"', lx_text)
if not lx_roles or not lx_outputs:
    fail("bin/lx is missing THEME_ROLES or THEME_OUTPUTS")
else:
    roles = lx_roles.group(1).split()
    if set(roles) != set(gtk3_palette):
        fail(f"THEME_ROLES in bin/lx differs from the fallback palettes: {sorted(set(roles) ^ set(gtk3_palette))}")
    else:
        print(f"    OK    bin/lx checks the same {len(roles)} roles as the fallback palettes")

    HEXV = r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?"
    KITTY_KEYS = ("foreground background selection_foreground selection_background cursor cursor_text_color "
                  + " ".join(f"color{i}" for i in range(16))).split()

    def lx_accepts(name, text):
        """Python copy of theme_validate in bin/lx. Returns what's missing."""
        missing = []

        def need(pattern, label):
            if not re.search(pattern, text, re.M):
                missing.append(label)

        if name == "colors.css":
            for r in roles:
                need(rf"^@define-color[ \t]+{r}[ \t]+{HEXV};", r)
        elif name == "colors.rasi":
            for r in roles:
                need(rf"^[ \t]*{r.replace('_', '-')}:[ \t]*{HEXV};", r)
        elif name == "colors-gtk4.css":
            for r in roles:
                need(rf"^[ \t]*--{r}:[ \t]*{HEXV};", r)
        elif name == "colors-hyprlock.conf":
            for r in roles:
                need(rf"^\${r}[ \t]*=[ \t]*[0-9]{{1,3}},[ \t]*[0-9]{{1,3}},[ \t]*[0-9]{{1,3}}[ \t]*$", r)
        elif name == "colors-kitty.conf":
            for k in KITTY_KEYS:
                need(rf"^{k}[ \t]+{HEXV}[ \t]*$", k)
        elif name == "colors.lua":
            need(r"^return \{", "return {")
            need(r'active_border[ \t]*=.*"rgba\([0-9a-fA-F]{8}\)"', "active_border")
            need(r'inactive_border[ \t]*=[ \t]*"rgba\([0-9a-fA-F]{8}\)"', "inactive_border")
            need(r"shadow[ \t]*=[ \t]*0x[0-9a-fA-F]{8}", "shadow")
        else:
            missing.append("unknown output file")
        return missing

    # Rendered files must use exactly the names their fallback uses.
    FALLBACK_NAMES = {
        "colors.css": (parse_gtk3, gtk3_palette),
        "colors.rasi": (parse_rasi, rasi_palette),
        "colors-gtk4.css": (parse_gtk4, gtk4_palette),
        "colors-hyprlock.conf": (parse_hyprlock, lock_palette),
        "colors-kitty.conf": (parse_kitty, kitty_palette),
    }

    cfg_path = f"{REPO}/config/matugen/config.toml"
    try:
        matugen_cfg = tomllib.load(open(cfg_path, "rb"))
    except Exception as e:
        fail(f"{rel(cfg_path)}: not valid TOML: {e}")
        matugen_cfg = {}
    if matugen_cfg:
        c = matugen_cfg.get("config", {})
        if c.get("source_color_index") != 0:
            fail(f"{rel(cfg_path)}: source_color_index must be 0, or matugen may stop to ask for a color")
        templates = matugen_cfg.get("templates", {})
        outputs = {}
        for tname, t in templates.items():
            out = t.get("output_path", "")
            if not out.startswith("~/.cache/lynx/theme/staging/"):
                fail(f"template {tname}: output must go to ~/.cache/lynx/theme/staging/, not {out!r}")
            outputs[os.path.basename(out)] = (tname, t)
        if set(outputs) != set(lx_outputs.group(1).split()):
            fail(f"templates {sorted(outputs)} don't match THEME_OUTPUTS in bin/lx {sorted(lx_outputs.group(1).split())}")

        for out_name, (tname, t) in sorted(outputs.items()):
            src = os.path.normpath(os.path.join(os.path.dirname(cfg_path), t["input_path"]))
            if not os.path.exists(src):
                fail(f"template {tname}: input {t['input_path']} doesn't exist")
                continue
            problems = []
            for mode in ("dark", "light"):
                try:
                    rendered = rt.render(read(src), mode)
                except rt.RenderError as e:
                    problems += e.args[0]
                    break
                missing = lx_accepts(out_name, rendered)
                if missing:
                    problems.append(f"{mode}: lx would reject it, missing {missing}")
                if out_name in FALLBACK_NAMES:
                    parser, fallback = FALLBACK_NAMES[out_name]
                    if set(parser(rendered)) != set(fallback):
                        problems.append(f"names differ from fallback: {sorted(set(parser(rendered)) ^ set(fallback))}")
                if out_name == "colors.lua" and ast is not None:
                    try:
                        ast.parse(rendered)
                    except Exception as e:
                        problems.append(f"rendered Lua doesn't parse: {str(e).splitlines()[0][:120]}")
            if problems:
                fail(f"{rel(src)}: {'; '.join(dict.fromkeys(problems))}")
            else:
                print(f"    OK    {rel(src)} -> {out_name} (dark + light)")

# [9] ──────────────────────────────────────────────────────────────────────────
print("[9] line endings")
crlf = []
for root, dirs, files in os.walk(REPO):
    dirs[:] = [d for d in dirs if d not in (".git", "__pycache__")]
    for name in files:
        if name.endswith((".png", ".jpg", ".webp")):
            continue
        path = os.path.join(root, name)
        if b"\r\n" in open(path, "rb").read():
            crlf.append(rel(path))
print(f"    CRLF files: {crlf or 'none'}")
if crlf:
    fail(f"CRLF in {crlf}")

print("\nALL CHECKS PASSED" if not failed else f"\n{failed} CHECK(S) FAILED")
sys.exit(1 if failed else 0)
