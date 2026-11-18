#!/usr/bin/env python3
"""Generate the fastfetch configs used by the zsh greeter.

Writes two profiles into ~/.config/fastfetch:

  config.jsonc    full size, for a roughly full-width terminal
  compact.jsonc   narrow, for a half-tiled window

Generated rather than hand-written because the keys embed raw ANSI colour
escapes (so each icon can be coloured independently of its label) and because
the box border only lines up if every key is padded to exactly the same
*visible* width -- fastfetch's own key.width aligns values with a cursor-jump
escape (\\e[14G), which moves the value but leaves the separator glued to the
end of the key, so it cannot hold a right-hand border in place.

Each profile prints its widest row; keep that under the terminal width it
targets, or long values wrap back underneath the logo and break the box.
"""
import json
import os

E = "\x1b"
ICON_W = 1        # cells a Nerd Font glyph occupies; verified on screen

# (module type, icon, 256-colour code, label, extra module options)
ROWS = [
    ("title",    "\U000F0004", 111, "user",    {"format": "{user-name}"}),
    ("title",    "\U000F0322", 111, "hname",   {"format": "{host-name}"}),
    ("uptime",   "\U000F0150", 117, "uptime",  {}),
    ("os",       "\U000F08C7",  43, "distro",  {}),
    ("kernel",   "\U000F033D", 208, "kernel",  {"format": "{sysname} {release}"}),
    ("wm",       "\U000F0614", 141, "desktop", {}),
    ("terminal", "\U000F018D",  79, "term",    {}),
    ("shell",    "\U000F1183",  49, "shell",   {}),
    ("cpu",      "\U000F0EE0", 203, "cpu",     {}),
    ("gpu",      "\U000F08AE",  77, "gpu",     {"detectionMethod": "pci",
                                               "format": "{name} [{type}]"}),
    ("disk",     "\U000F02CA", 221, "disk",    {"folders": "/"}),
    ("memory",   "\U000F035B", 213, "memory",  {}),
    ("colors",   "\U000F03D8", 176, "colors",  {"symbol": "circle"}),
]

PROFILES = {
    # name          box  logo w/h  pad l/r  per-module overrides
    "config":  dict(box=14, logo=(24, 12), pad=(2, 3), overrides={}),
    "compact": dict(box=12, logo=(14, 7),  pad=(1, 2), overrides={
        # The CPU line is what overflows first: the stock format adds the
        # P/E core count, which no longer fits beside a logo at ~80 columns.
        "cpu": {"format": "{name} @ {freq-max}"},
    }),
}


def key_for(box, icon, colour, label):
    """`│ <icon> <label>` padded so the separator always lands on one column."""
    visible = 1 + 1 + ICON_W + 1 + len(label)
    return f"│ {E}[38;5;{colour}m{icon}{E}[39m {label}" + " " * max(0, box - visible)


def build(profile):
    box = profile["box"]
    rule = lambda l, r: f"{E}[38;5;240m" + l + "─" * (box - 1) + r + f"{E}[0m"

    modules = [{"type": "custom", "format": rule("╭", "╮")}]
    for mtype, icon, colour, label, extra in ROWS:
        mod = {"type": mtype, "key": key_for(box, icon, colour, label)}
        mod.update(extra)
        mod.update(profile["overrides"].get(mtype, {}))
        modules.append(mod)
    modules.append({"type": "custom", "format": rule("╰", "╯")})

    return {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "logo": {
            "type": "kitty-direct",
            # Left as ~: fastfetch expands it itself, so the generated files
            # (which the dotfiles repo ships) work for any user.
            "source": "~/.config/fastfetch/cachyos.png",
            "width": profile["logo"][0],
            "height": profile["logo"][1],
            "padding": {"top": 1, "left": profile["pad"][0], "right": profile["pad"][1]},
        },
        "display": {
            "separator": f"{E}[38;5;240m│{E}[0m ",
            "color": {"keys": "white", "title": "green"},
            "percent": {"type": 9},
            "size": {"ndigits": 2},
        },
        "modules": modules,
    }


def main():
    for name, profile in PROFILES.items():
        out = os.path.expanduser(f"~/.config/fastfetch/{name}.jsonc")
        with open(out, "w") as f:
            json.dump(build(profile), f, indent=2, ensure_ascii=False)
            f.write("\n")
        block = profile["pad"][0] + profile["logo"][0] + profile["pad"][1]
        print(f"{out}  (logo block {block} cols)")


if __name__ == "__main__":
    main()
