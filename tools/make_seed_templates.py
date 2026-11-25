#!/usr/bin/env python3
"""Generates the letter templates for every style as JSON.

All shapes are our own geometry (arcs, lines and smooth curves defined here).
Units are line units: y=0 ascender line, 0.5 x-height, 1.0 baseline,
1.5 descender line; x grows to the right.

Styles:
  print-modern         "Normal": ball-and-stick print
  cursive-modern       "Classic": upright joined letters, plain ascenders
  cursive-traditional  "Traditional": slanted joined letters with loops
Each cursive style also accepts the other's looped/plain form of b f h k l
and the descender letters as an alternate, so either is scored as correct.
"""
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "content/templates/latin")
SLANT = math.tan(math.radians(18))  # Traditional lean


# ---------------------------------------------------------------- helpers

def arc(cx, cy, rx, ry, start_deg, end_deg, n=28):
    """Elliptical arc; increasing angle runs counter-clockwise on screen."""
    pts = []
    for i in range(n):
        a = math.radians(start_deg + (end_deg - start_deg) * i / (n - 1))
        pts.append([cx + rx * math.cos(a), cy - ry * math.sin(a)])
    return pts


def line(*pts):
    return [list(p) for p in pts]


def spline(*points, steps=8):
    """Smooth Catmull-Rom curve through the points."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            out.append([
                0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3)
                for j in (0, 1)
            ])
    out.append(list(points[-1]))
    return out


def joined(*pieces):
    """One stroke made of pieces that meet at sharp corners."""
    out = []
    for piece in pieces:
        out.extend(piece if not out else piece[1:])
    return out


S = spline
J = joined

# ---------------------------------------------------------------- print ("Normal")

BOWL = dict(cx=0.24, cy=0.75, rx=0.2, ry=0.25)


def print_letters():
    bowl = arc(**BOWL, start_deg=20, end_deg=380, n=36)
    right_bowl = arc(0.27, 0.75, 0.19, 0.25, 170, -170, n=36)  # b, p: clockwise from the stem
    return {
        "a": dict(strokes=[bowl, line((0.44, 0.5), (0.44, 1.0))],
                  alternates=[[bowl + line((0.44, 0.5), (0.44, 1.0))]]),
        "b": dict(strokes=[line((0.08, 0.0), (0.08, 1.0)), right_bowl]),
        "c": dict(strokes=[arc(0.25, 0.75, 0.22, 0.25, 40, 320)]),
        "d": dict(strokes=[bowl, line((0.44, 0.0), (0.44, 1.0))]),
        "e": dict(strokes=[J(line((0.05, 0.75), (0.45, 0.75)), arc(0.25, 0.75, 0.2, 0.25, 0, 320))]),
        "f": dict(strokes=[J(arc(0.30, 0.18, 0.12, 0.12, 30, 180, n=14), line((0.18, 0.18), (0.18, 1.0))),
                           line((0.04, 0.5), (0.36, 0.5))]),
        "g": dict(strokes=[bowl, J(line((0.44, 0.5), (0.44, 1.3)), arc(0.27, 1.3, 0.17, 0.17, 0, -160, n=16))]),
        "h": dict(strokes=[line((0.08, 0.0), (0.08, 1.0)),
                           J(arc(0.25, 0.72, 0.17, 0.2, 180, 0, n=18), line((0.42, 0.72), (0.42, 1.0)))]),
        "i": dict(strokes=[line((0.1, 0.5), (0.1, 1.0)), line((0.1, 0.3), (0.1, 0.31))]),
        "j": dict(strokes=[J(line((0.3, 0.5), (0.3, 1.3)), arc(0.15, 1.3, 0.15, 0.17, 0, -170, n=16)),
                           line((0.3, 0.3), (0.3, 0.31))]),
        "k": dict(strokes=[line((0.08, 0.0), (0.08, 1.0)), line((0.40, 0.5), (0.08, 0.78), (0.42, 1.0))],
                  alternates=[[line((0.08, 0.0), (0.08, 1.0)), line((0.40, 0.5), (0.08, 0.78)),
                               line((0.2, 0.7), (0.42, 1.0))]]),
        "l": dict(strokes=[line((0.1, 0.0), (0.1, 1.0))]),
        "m": dict(strokes=[line((0.06, 0.5), (0.06, 1.0)),
                           J(arc(0.2, 0.7, 0.14, 0.18, 180, 0, n=16), line((0.34, 0.7), (0.34, 1.0))),
                           J(arc(0.48, 0.7, 0.14, 0.18, 180, 0, n=16), line((0.62, 0.7), (0.62, 1.0)))]),
        "n": dict(strokes=[line((0.06, 0.5), (0.06, 1.0)),
                           J(arc(0.24, 0.7, 0.18, 0.18, 180, 0, n=18), line((0.42, 0.7), (0.42, 1.0)))]),
        "o": dict(strokes=[arc(0.26, 0.75, 0.22, 0.25, 70, 430, n=36)]),
        "p": dict(strokes=[line((0.08, 0.5), (0.08, 1.5)), right_bowl]),
        "q": dict(strokes=[bowl, line((0.44, 0.5), (0.44, 1.5))]),
        "r": dict(strokes=[line((0.08, 0.5), (0.08, 1.0)), arc(0.24, 0.68, 0.16, 0.16, 180, 40, n=14)]),
        "s": dict(strokes=[S((0.40, 0.58), (0.25, 0.5), (0.09, 0.58), (0.11, 0.71), (0.25, 0.76),
                             (0.38, 0.82), (0.40, 0.94), (0.25, 1.0), (0.06, 0.93))]),
        "t": dict(strokes=[line((0.15, 0.15), (0.15, 1.0)), line((0.0, 0.5), (0.32, 0.5))]),
        "u": dict(strokes=[J(line((0.06, 0.5), (0.06, 0.8)), arc(0.24, 0.8, 0.18, 0.2, 180, 360, n=18),
                             line((0.42, 0.8), (0.42, 0.5))),
                           line((0.42, 0.5), (0.42, 1.0))]),
        "v": dict(strokes=[line((0.0, 0.5), (0.22, 1.0), (0.44, 0.5))]),
        "w": dict(strokes=[line((0.0, 0.5), (0.15, 1.0), (0.3, 0.6), (0.45, 1.0), (0.6, 0.5))]),
        "x": dict(strokes=[line((0.02, 0.5), (0.42, 1.0)), line((0.42, 0.5), (0.02, 1.0))]),
        "y": dict(strokes=[line((0.02, 0.5), (0.24, 1.0)), line((0.46, 0.5), (0.12, 1.5))]),
        "z": dict(strokes=[line((0.04, 0.5), (0.42, 0.5), (0.04, 1.0), (0.44, 1.0))]),
    }


# ---------------------------------------------------------------- cursive skeleton
# Round letters start at the top; others start with a lead-in from the baseline.
# Every letter ends with an exit stroke so letters can join.

CBOWL = [(0.46, 0.52), (0.31, 0.50), (0.16, 0.57), (0.09, 0.75), (0.16, 0.94), (0.30, 1.0), (0.40, 0.92),
         (0.44, 0.72), (0.46, 0.52)]


def exit_at(x, top=0.52):
    return S((x, top), (x + 0.01, 0.8), (x + 0.04, 0.96), (x + 0.12, 1.0), (x + 0.22, 0.9))


def ascender(x, looped):
    """Lead-in from the baseline up to the ascender line, then down to the baseline at x."""
    if looped:
        return S((0.0, 1.0), (x + 0.01, 0.75), (x + 0.12, 0.38), (x + 0.15, 0.13), (x + 0.09, 0.02),
                 (x + 0.01, 0.12), (x - 0.01, 0.45), (x, 1.0))
    return J(S((0.0, 1.0), (x * 0.6, 0.75), (x * 0.95, 0.35), (x, 0.0)), line((x, 0.0), (x, 1.0)))


def descender(x, looped):
    """From the x-height down below the baseline at x, then a loop back up or a plain hook."""
    down = line((x, 0.52), (x, 1.28))
    if looped:
        return J(down, S((x, 1.28), (x - 0.02, 1.44), (x - 0.1, 1.48), (x - 0.13, 1.4), (x - 0.04, 1.18),
                         (x + 0.1, 1.0), (x + 0.22, 0.9)))
    return J(down, S((x, 1.28), (x - 0.04, 1.44), (x - 0.13, 1.49), (x - 0.22, 1.42)))


def hump(x0, x1, end_exit=False):
    """An arch from the baseline at x0 over to x1 and back down."""
    mid = (x0 + x1) / 2
    up = S((x0, 1.0), (x0 + 0.02, 0.74), (mid - 0.02, 0.55), (mid + 0.05, 0.53), (x1, 0.64))
    if end_exit:
        return J(up, S((x1, 0.64), (x1, 0.9), (x1 + 0.04, 1.0), (x1 + 0.14, 0.97), (x1 + 0.22, 0.88)))
    return J(up, line((x1, 0.64), (x1, 1.0)))


def lead(x, y=0.5):
    return S((0.0, 1.0), (x * 0.45, 0.82), (x * 0.85, 0.58), (x, y))


def cursive_letters(looped):
    L = looped
    letters = {
        "a": [J(S(*CBOWL), exit_at(0.46))],
        "b": [J(ascender(0.14, L), S((0.14, 1.0), (0.2, 0.92), (0.33, 0.74), (0.38, 0.6), (0.33, 0.54),
                                      (0.30, 0.6), (0.42, 0.6), (0.56, 0.55)))],
        "c": [S((0.44, 0.58), (0.36, 0.51), (0.22, 0.51), (0.11, 0.62), (0.09, 0.80), (0.18, 0.96), (0.32, 1.0),
                (0.48, 0.94), (0.64, 0.82))],
        "d": [J(S(*CBOWL), line((0.46, 0.52), (0.47, 0.0)), exit_at(0.47, top=0.0))],
        "e": [S((0.0, 1.0), (0.12, 0.86), (0.30, 0.74), (0.40, 0.64), (0.36, 0.54), (0.26, 0.53), (0.18, 0.62),
                (0.16, 0.80), (0.22, 0.95), (0.34, 1.0), (0.46, 0.94), (0.56, 0.84))],
        "f": ([S((0.0, 1.0), (0.14, 0.7), (0.26, 0.3), (0.28, 0.08), (0.22, 0.02), (0.15, 0.1), (0.15, 0.5),
                 (0.15, 1.0), (0.15, 1.3), (0.13, 1.45), (0.08, 1.42), (0.1, 1.2), (0.22, 1.0), (0.32, 0.92),
                 (0.45, 0.84))]
              if L else
              [J(S((0.0, 1.0), (0.1, 0.75), (0.17, 0.35), (0.2, 0.02)), line((0.2, 0.02), (0.2, 1.3)),
                 S((0.2, 1.3), (0.17, 1.45), (0.09, 1.48), (0.02, 1.42))),
               line((0.04, 0.5), (0.36, 0.5))]),
        "g": [J(S(*CBOWL), descender(0.46, L))],
        "h": [J(ascender(0.14, L), hump(0.14, 0.42, end_exit=True))],
        "i": [J(lead(0.2), S((0.2, 0.5), (0.2, 0.75), (0.22, 0.94), (0.30, 1.0), (0.41, 0.93), (0.50, 0.82))),
              line((0.2, 0.3), (0.2, 0.31))],
        "j": [J(lead(0.2), descender(0.2, L)), line((0.2, 0.3), (0.2, 0.31))],
        "k": [J(ascender(0.14, L), S((0.14, 1.0), (0.18, 0.72), (0.3, 0.56), (0.4, 0.58), (0.38, 0.7),
                                      (0.24, 0.76), (0.36, 0.8), (0.42, 0.95), (0.5, 1.0), (0.62, 0.9)))],
        "l": [J(ascender(0.16, L), S((0.16, 1.0), (0.24, 1.0), (0.36, 0.95), (0.47, 0.84)))],
        "m": [J(lead(0.12, 0.54), line((0.12, 0.54), (0.12, 1.0)), hump(0.12, 0.36), hump(0.36, 0.6, end_exit=True))],
        "n": [J(lead(0.12, 0.54), line((0.12, 0.54), (0.12, 1.0)), hump(0.12, 0.4, end_exit=True))],
        "o": [J(S((0.38, 0.52), (0.22, 0.52), (0.11, 0.66), (0.10, 0.85), (0.20, 0.98), (0.34, 1.0), (0.46, 0.9),
                  (0.49, 0.72), (0.43, 0.56), (0.36, 0.52)),
                S((0.36, 0.52), (0.46, 0.57), (0.57, 0.56), (0.68, 0.52)))],
        "p": [J(lead(0.16), line((0.16, 0.5), (0.16, 1.48)), line((0.16, 1.48), (0.16, 0.9)),
                S((0.16, 0.9), (0.2, 0.66), (0.3, 0.53), (0.42, 0.56), (0.46, 0.72), (0.42, 0.92), (0.3, 1.0),
                  (0.2, 0.96)),
                S((0.2, 0.96), (0.36, 1.0), (0.5, 0.96), (0.6, 0.88)))],
        "q": [J(S(*CBOWL), line((0.46, 0.52), (0.46, 1.42)),
                S((0.46, 1.42), (0.5, 1.28), (0.58, 1.1), (0.68, 0.98), (0.76, 0.9)))],
        "r": [J(lead(0.24), S((0.24, 0.5), (0.31, 0.57), (0.38, 0.56)),
                S((0.38, 0.56), (0.36, 0.75), (0.38, 0.95), (0.46, 1.0), (0.56, 0.95), (0.64, 0.86)))],
        "s": [J(lead(0.28), S((0.28, 0.5), (0.36, 0.68), (0.4, 0.84), (0.34, 0.98), (0.22, 1.0), (0.14, 0.94)),
                S((0.14, 0.94), (0.26, 0.99), (0.4, 0.98), (0.52, 0.9)))],
        "t": [J(S((0.0, 1.0), (0.10, 0.78), (0.17, 0.45), (0.21, 0.15)),
                S((0.21, 0.15), (0.21, 0.55), (0.22, 0.86), (0.30, 1.0), (0.42, 0.93), (0.51, 0.82))),
              line((0.06, 0.48), (0.38, 0.48))],
        "u": [J(lead(0.14), S((0.14, 0.5), (0.14, 0.8), (0.18, 0.96), (0.26, 1.0), (0.36, 0.94), (0.4, 0.75),
                              (0.4, 0.5)), exit_at(0.4, top=0.5))],
        "v": [J(lead(0.18, 0.52), S((0.18, 0.52), (0.2, 0.7), (0.26, 0.92), (0.32, 1.0), (0.38, 0.9), (0.42, 0.7),
                                    (0.44, 0.52)), S((0.44, 0.52), (0.5, 0.56), (0.58, 0.56), (0.66, 0.52)))],
        "w": [J(lead(0.14), S((0.14, 0.5), (0.15, 0.8), (0.2, 0.97), (0.27, 1.0), (0.33, 0.9), (0.35, 0.65)),
                S((0.35, 0.65), (0.37, 0.88), (0.43, 1.0), (0.5, 0.96), (0.55, 0.75), (0.56, 0.52)),
                S((0.56, 0.52), (0.62, 0.56), (0.7, 0.56), (0.78, 0.52)))],
        "x": [J(lead(0.22), S((0.22, 0.5), (0.3, 0.7), (0.38, 0.9), (0.44, 1.0), (0.54, 0.94), (0.62, 0.86))),
              line((0.44, 0.52), (0.2, 0.98))],
        "y": [J(lead(0.14), S((0.14, 0.5), (0.14, 0.8), (0.18, 0.96), (0.26, 1.0), (0.36, 0.94), (0.4, 0.75),
                              (0.4, 0.52)), descender(0.4, L))],
        "z": [J(lead(0.2, 0.52), S((0.2, 0.52), (0.32, 0.5), (0.42, 0.56), (0.34, 0.72), (0.22, 0.86)),
                S((0.22, 0.86), (0.36, 0.88), (0.42, 1.0), (0.42, 1.28), (0.38, 1.44), (0.3, 1.48), (0.26, 1.4),
                  (0.34, 1.18), (0.48, 1.0), (0.6, 0.9))
                if L else
                S((0.22, 0.86), (0.36, 0.9), (0.42, 1.0), (0.52, 1.0), (0.62, 0.92)))],
    }
    return letters


# Letters whose looped and plain forms differ (each style accepts the other).
LOOP_LETTERS = set("bfhklgjyz")


def slanted(strokes):
    return [[[x + (1.0 - y) * SLANT, y] for x, y in s] for s in strokes]


def styles():
    out = {"print-modern": print_letters(), "cursive-modern": {}, "cursive-traditional": {}}
    plain, loops = cursive_letters(False), cursive_letters(True)
    for g in plain:
        alt_plain = [loops[g]] if g in LOOP_LETTERS else []
        out["cursive-modern"][g] = dict(strokes=plain[g], alternates=alt_plain)
        alt_trad = [slanted(plain[g])] if g in LOOP_LETTERS else []
        out["cursive-traditional"][g] = dict(strokes=slanted(loops[g]), alternates=alt_trad)
    return out


# ---------------------------------------------------------------- output

def file_name(glyph):
    """Unicode code points, e.g. a -> 0061. Safe on case-insensitive disks (a vs A)."""
    return "_".join(f"{ord(ch):04X}" for ch in glyph) + ".json"


def normalise(spec):
    """Moves the letter so its left edge is at x=0 and measures its width."""
    forms = [spec["strokes"]] + spec.get("alternates", [])
    min_x = min(p[0] for form in forms for s in form for p in s)
    max_x = max(p[0] for form in forms for s in form for p in s)
    r = lambda form: [{"points": [[round(x - min_x, 4), round(y, 4)] for x, y in s]} for s in form]
    return r(spec["strokes"]), [r(f) for f in spec.get("alternates", [])], round(max_x - min_x, 4)


def main():
    for style, letters in styles().items():
        out = ROOT / style
        out.mkdir(parents=True, exist_ok=True)
        for glyph, spec in letters.items():
            strokes, alternates, width = normalise(spec)
            doc = {"id": f"latin.{style}.{glyph}", "glyph": glyph, "script": "latin", "style": style,
                   "width": max(width, 0.2), "strokes": strokes}
            if alternates:
                doc["alternates"] = alternates
            (out / file_name(glyph)).write_text(json.dumps(doc, indent=1) + "\n")
        print(f"{style}: {len(letters)} letters")


if __name__ == "__main__":
    main()
