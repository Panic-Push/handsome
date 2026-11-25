#!/usr/bin/env python3
"""Generates the seed letter templates (modern print) as JSON.

These are geometric starting points. They will be replaced or refined with
templates recorded on the iPad using the in-app Template Recorder.

Units: line units. y=0 ascender, 0.5 x-height, 1.0 baseline, 1.5 descender.
"""
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "content/templates/latin")


def arc(cx, cy, rx, ry, start_deg, end_deg, n=28):
    # Angles in the usual maths sense (counter-clockwise, y up), drawn on a
    # y-down screen, so increasing angle = counter-clockwise on screen.
    pts = []
    for i in range(n):
        a = math.radians(start_deg + (end_deg - start_deg) * i / (n - 1))
        pts.append([round(cx + rx * math.cos(a), 4), round(cy - ry * math.sin(a), 4)])
    return pts


def line(x1, y1, x2, y2):
    return [[x1, y1], [x2, y2]]


def spline(*points, steps=8):
    """Smooth Catmull-Rom curve through the given (x, y) points."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append([
                round(0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3), 4),
                round(0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3), 4),
            ])
    out.append([round(points[-1][0], 4), round(points[-1][1], 4)])
    return out


def joined(*pieces):
    """Joins curve pieces into one stroke with sharp corners where they meet."""
    out = []
    for piece in pieces:
        out.extend(piece if not out else piece[1:])
    return out


def stroke(points):
    return {"points": points}


BOWL = dict(cx=0.24, cy=0.75, rx=0.2, ry=0.25)

LETTERS = {
    "c": dict(width=0.5, strokes=[arc(0.25, 0.75, 0.22, 0.25, 40, 320)]),
    "o": dict(width=0.52, strokes=[arc(0.26, 0.75, 0.22, 0.25, 70, 430, n=36)]),
    "a": dict(
        width=0.5,
        strokes=[arc(**BOWL, start_deg=20, end_deg=380, n=36), line(0.44, 0.5, 0.44, 1.0)],
        alternates=[[arc(**BOWL, start_deg=20, end_deg=380, n=36) + [[0.44, 0.5], [0.44, 1.0]]]],
    ),
    "d": dict(
        width=0.5,
        strokes=[arc(**BOWL, start_deg=20, end_deg=380, n=36), line(0.44, 0.0, 0.44, 1.0)],
    ),
    "l": dict(width=0.2, strokes=[line(0.1, 0.0, 0.1, 1.0)]),
    "t": dict(width=0.34, strokes=[line(0.15, 0.15, 0.15, 1.0), line(0.0, 0.5, 0.32, 0.5)]),
    "i": dict(width=0.2, strokes=[line(0.1, 0.5, 0.1, 1.0), line(0.1, 0.3, 0.1, 0.31)]),
}


# Modern cursive: letters end with an exit stroke so they can join; tall and
# narrow letters (l t i) start with a lead-in from the baseline. Upright to start.
CURSIVE_BOWL = [(0.46, 0.52), (0.31, 0.50), (0.16, 0.57), (0.09, 0.75), (0.16, 0.94), (0.30, 1.0), (0.40, 0.92), (0.44, 0.72), (0.46, 0.52)]
CURSIVE_EXIT = [(0.47, 0.52), (0.47, 0.80), (0.50, 0.96), (0.58, 1.0), (0.68, 0.90)]

CURSIVE = {
    # Round letters (c o a d) start at the top, like print, and end with an exit stroke.
    "c": dict(width=0.66, strokes=[spline(
        (0.44, 0.58), (0.36, 0.51), (0.22, 0.51), (0.11, 0.62), (0.09, 0.80), (0.18, 0.96), (0.32, 1.0), (0.48, 0.94), (0.64, 0.82),
    )]),
    "o": dict(width=0.68, strokes=[joined(
        spline((0.38, 0.52), (0.22, 0.52), (0.11, 0.66), (0.10, 0.85), (0.20, 0.98), (0.34, 1.0), (0.46, 0.9), (0.49, 0.72), (0.43, 0.56), (0.36, 0.52)),
        spline((0.36, 0.52), (0.46, 0.57), (0.57, 0.56), (0.68, 0.52)),
    )]),
    "a": dict(width=0.68, strokes=[joined(spline(*CURSIVE_BOWL), spline(*CURSIVE_EXIT))]),
    "d": dict(width=0.68, strokes=[joined(
        spline(*CURSIVE_BOWL),
        spline((0.46, 0.52), (0.47, 0.25), (0.47, 0.0)),
        spline((0.47, 0.0), (0.47, 0.5), (0.47, 0.80), (0.50, 0.96), (0.58, 1.0), (0.68, 0.90)),
    )]),
    "l": dict(width=0.5, strokes=[spline(
        (0.0, 1.0), (0.15, 0.75), (0.28, 0.38), (0.31, 0.13), (0.24, 0.02), (0.16, 0.12), (0.14, 0.45), (0.15, 0.80), (0.22, 0.98), (0.35, 0.96), (0.47, 0.84),
    )]),
    "t": dict(width=0.52, strokes=[
        joined(
            spline((0.0, 1.0), (0.10, 0.78), (0.17, 0.45), (0.21, 0.15)),
            spline((0.21, 0.15), (0.21, 0.55), (0.22, 0.86), (0.30, 1.0), (0.42, 0.93), (0.51, 0.82)),
        ),
        line(0.06, 0.48, 0.38, 0.48),
    ]),
    "i": dict(width=0.5, strokes=[
        joined(
            spline((0.0, 1.0), (0.09, 0.82), (0.16, 0.6), (0.20, 0.5)),
            spline((0.20, 0.5), (0.20, 0.75), (0.22, 0.94), (0.30, 1.0), (0.41, 0.93), (0.50, 0.82)),
        ),
        line(0.2, 0.3, 0.2, 0.31),
    ]),
}

STYLES = {"print-modern": LETTERS, "cursive-modern": CURSIVE}


def file_name(glyph):
    """Unicode code points, e.g. a -> 0061. Safe on case-insensitive disks (a vs A)."""
    return "_".join(f"{ord(ch):04X}" for ch in glyph) + ".json"


def main():
    for style, letters in STYLES.items():
        out = ROOT / style
        out.mkdir(parents=True, exist_ok=True)
        for glyph, spec in letters.items():
            write(out, style, glyph, spec)


def write(out, style, glyph, spec):
    doc = {
        "id": f"latin.{style}.{glyph}",
        "glyph": glyph,
        "script": "latin",
        "style": style,
        "width": spec["width"],
        "strokes": [stroke(s) for s in spec["strokes"]],
    }
    if spec.get("alternates"):
        doc["alternates"] = [[stroke(s) for s in form] for form in spec["alternates"]]
    path = out / file_name(glyph)
    path.write_text(json.dumps(doc, indent=2) + "\n")
    print("wrote", path, "for", glyph)


if __name__ == "__main__":
    main()
