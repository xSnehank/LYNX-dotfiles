"""Render LYNX's matugen templates without matugen.

Two jobs:
  1. The repo check imports this to prove every template uses only syntax and
     color names that matugen 4.2.0 really has, and renders into a file that
     `lx` accepts.
  2. The lx smoke test runs it as a stand-in for the `matugen` command.

It implements only the small part of matugen's template language LYNX uses:

    {{ colors.<role>.<default|dark|light>.<hex|hex_stripped|red|green|blue> }}
    {{ base16.<base00..base0f>.<default|dark|light>.<hex|hex_stripped> }}

Anything else is reported as an error, so a typo or an unsupported feature
fails the check instead of reaching matugen. Colors are fake but stable.
"""
import hashlib
import os
import re
import sys
import tomllib

# The fields of material-colors 0.4.0's Scheme struct (the crate matugen 4.2.0
# uses). These are the names matugen offers as colors.<role>.
ROLES = set("""
primary on_primary primary_container on_primary_container inverse_primary primary_fixed
primary_fixed_dim on_primary_fixed on_primary_fixed_variant secondary on_secondary
secondary_container on_secondary_container secondary_fixed secondary_fixed_dim on_secondary_fixed
on_secondary_fixed_variant tertiary on_tertiary tertiary_container on_tertiary_container
tertiary_fixed tertiary_fixed_dim on_tertiary_fixed on_tertiary_fixed_variant error on_error
error_container on_error_container surface_dim surface surface_tint surface_bright
surface_container_lowest surface_container_low surface_container surface_container_high
surface_container_highest on_surface on_surface_variant outline outline_variant inverse_surface
inverse_on_surface surface_variant background on_background shadow scrim
""".split())

# matugen 4.2.0's base16 keys (src/color/base16.rs), lowercase.
BASE16 = {f"base0{c}" for c in "0123456789abcdef"}

EXPR = re.compile(r"\{\{\s*(.*?)\s*\}\}")
COLOR_EXPR = re.compile(r"^colors\.([a-z_]+)\.(default|dark|light)\.(hex|hex_stripped|red|green|blue)$")
BASE16_EXPR = re.compile(r"^base16\.([a-z0-9]+)\.(default|dark|light)\.(hex|hex_stripped)$")


class RenderError(Exception):
    pass


def fake_rgb(name, mode):
    digest = hashlib.sha1(f"{mode}:{name}".encode()).digest()
    return digest[0], digest[1], digest[2]


def render(text, mode="dark"):
    if "<*" in text:
        raise RenderError(["block syntax <* ... *> is not used by LYNX templates"])
    errors = []

    def substitute(match):
        expr = match.group(1)
        color = COLOR_EXPR.match(expr)
        base16 = BASE16_EXPR.match(expr)
        if color:
            name, which, fmt = color.groups()
            if name not in ROLES:
                errors.append(f"unknown color role: {name}")
                return ""
        elif base16:
            name, which, fmt = base16.groups()
            if name not in BASE16:
                errors.append(f"unknown base16 key: {name}")
                return ""
        else:
            errors.append(f"unsupported expression: {{{{ {expr} }}}}")
            return ""
        r, g, b = fake_rgb(name, mode if which == "default" else which)
        return {
            "hex": f"#{r:02x}{g:02x}{b:02x}",
            "hex_stripped": f"{r:02x}{g:02x}{b:02x}",
            "red": str(r),
            "green": str(g),
            "blue": str(b),
        }[fmt]

    out = EXPR.sub(substitute, text)
    if "{{" in out or "}}" in out:
        errors.append("unbalanced {{ }}")
    if errors:
        raise RenderError(errors)
    return out


def _option(args, *names):
    for i, arg in enumerate(args):
        if arg in names and i + 1 < len(args):
            return args[i + 1]
    return None


def main(argv):
    """Behave like `matugen image PATH --config FILE --mode MODE ...`."""
    test_dir = os.environ.get("LXTEST_DIR")
    if test_dir:
        with open(os.path.join(test_dir, "matugen.args"), "w", encoding="utf-8") as f:
            f.write(" ".join(argv[1:]) + "\n")

    simulate = os.environ.get("LXTEST_MATUGEN", "")
    if simulate == "fail":
        print("matugen (fake): simulated failure", file=sys.stderr)
        return 2

    args = argv[1:]
    if not args or args[0] != "image":
        print("matugen (fake): only `image` is supported", file=sys.stderr)
        return 2
    config = _option(args, "--config", "-c")
    mode = _option(args, "--mode", "-m") or "dark"
    if not config:
        print("matugen (fake): --config is required", file=sys.stderr)
        return 2

    with open(config, "rb") as f:
        cfg = tomllib.load(f)
    base = os.path.dirname(os.path.abspath(config))
    home = os.environ.get("LXTEST_HOME") or os.environ.get("HOME") or os.path.expanduser("~")

    written = {}
    for name, template in cfg.get("templates", {}).items():
        if template.get("enabled", True) is False or not template.get("output_path"):
            continue
        src = template["input_path"]
        src = src if os.path.isabs(src) else os.path.join(base, src)
        out = template["output_path"]
        if out.startswith("~/"):
            out = os.path.join(home, out[2:])
        elif not os.path.isabs(out):
            out = os.path.join(base, out)
        with open(src, encoding="utf-8") as f:
            text = render(f.read(), mode)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        written[os.path.basename(out)] = out

    if simulate == "bad" and "colors-gtk4.css" in written:
        path = written["colors-gtk4.css"]
        lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
        open(path, "w", encoding="utf-8", newline="\n").write("".join(l for l in lines if "--error:" not in l))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except RenderError as e:
        print("matugen (fake): " + "; ".join(e.args[0]), file=sys.stderr)
        sys.exit(1)
