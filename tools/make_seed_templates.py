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

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "content/templates/latin/print-modern")


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


def file_name(glyph):
    """Unicode code points, e.g. a -> 0061. Safe on case-insensitive disks (a vs A)."""
    return "_".join(f"{ord(ch):04X}" for ch in glyph) + ".json"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for glyph, spec in LETTERS.items():
        doc = {
            "id": f"latin.print-modern.{glyph}",
            "glyph": glyph,
            "script": "latin",
            "style": "print-modern",
            "width": spec["width"],
            "strokes": [stroke(s) for s in spec["strokes"]],
        }
        if spec.get("alternates"):
            doc["alternates"] = [[stroke(s) for s in form] for form in spec["alternates"]]
        path = OUT / file_name(glyph)
        path.write_text(json.dumps(doc, indent=2) + "\n")
        print("wrote", path, "for", glyph)


if __name__ == "__main__":
    main()
