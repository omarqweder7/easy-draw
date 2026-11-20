"""Generates Easy Draw's bundled starter content.

All artwork here is original, hand-authored vector line art made for Easy Draw.
Each drawing is a list of steps; each step is a list of elements:
  "<path d>"            -> stroked line
  ("fill", "<path d>")  -> filled in the ink colour
  ("white", "<path d>") -> filled white (references only, not lessons)

The script writes:
  assets/library/<category>/<id>.svg
  assets/library/references.json
  assets/lessons/lessons.json

To add content: add a drawing below (or drop an SVG/PNG into
assets/library/<category>/ and add an entry to `REFS`), then run
  python tools/generate_content.py
"""
import json
import math
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
INK = "#1A1A1A"


def f(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def circle(cx, cy, r):
    return f"M{f(cx - r)} {f(cy)} A{f(r)} {f(r)} 0 1 0 {f(cx + r)} {f(cy)} A{f(r)} {f(r)} 0 1 0 {f(cx - r)} {f(cy)} Z"


def ellipse(cx, cy, rx, ry):
    return f"M{f(cx - rx)} {f(cy)} A{f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)} A{f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)} Z"


def rot(x, y, cx, cy, a):
    s, c = math.sin(a), math.cos(a)
    x, y = x - cx, y - cy
    return cx + x * c - y * s, cy + x * s + y * c


def leaf(x0, y0, x1, y1, w, rib=True):
    """Pointed oval from base (x0,y0) to tip (x1,y1), half-width w."""
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * w, dx / L * w
    a1 = (x0 + dx * 0.3 + nx, y0 + dy * 0.3 + ny)
    a2 = (x0 + dx * 0.75 + nx * 0.8, y0 + dy * 0.75 + ny * 0.8)
    b1 = (x0 + dx * 0.75 - nx * 0.8, y0 + dy * 0.75 - ny * 0.8)
    b2 = (x0 + dx * 0.3 - nx, y0 + dy * 0.3 - ny)
    d = (f"M{f(x0)} {f(y0)} C{f(a1[0])} {f(a1[1])} {f(a2[0])} {f(a2[1])} {f(x1)} {f(y1)} "
         f"C{f(b1[0])} {f(b1[1])} {f(b2[0])} {f(b2[1])} {f(x0)} {f(y0)} Z")
    out = [d]
    if rib:
        out.append(f"M{f(x0)} {f(y0)} Q{f(x0 + dx * 0.5 + nx * 0.15)} {f(y0 + dy * 0.5 + ny * 0.15)} {f(x0 + dx * 0.85)} {f(y0 + dy * 0.85)}")
    return out


def star(cx, cy, ro, ri, n=5, start=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = start + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts) + " Z"


def teardrop(x, y, s=1.0):
    return f"M{f(x)} {f(y)} Q{f(x - 9 * s)} {f(y + 16 * s)} {f(x)} {f(y + 22 * s)} Q{f(x + 9 * s)} {f(y + 16 * s)} {f(x)} {f(y)} Z"


def waves(x0, x1, y, amp=12, step=40):
    d = f"M{f(x0)} {f(y)} q{f(step / 2)} {f(-amp)} {f(step)} 0"
    x = x0 + step
    while x + step <= x1:
        d += f" t{f(step)} 0"
        x += step
    return d


def mirror_x(d, axis=200):
    """Mirrors absolute-coordinate path data (M/L/C/Q/A/Z only, absolute) across x=axis."""
    out, tokens = [], d.replace(",", " ").split()
    cmd, nums = None, []

    def flush():
        if cmd is None:
            return
        if cmd in "MLCQT":
            vals = [float(v) for v in nums]
            for i in range(0, len(vals), 2):
                vals[i] = 2 * axis - vals[i]
            out.append(cmd + " ".join(f(v) for v in vals))
        elif cmd == "A":
            vals = [float(v) for v in nums]
            for i in range(0, len(vals), 7):
                vals[i + 4] = 1 - vals[i + 4]  # sweep flag flips
                vals[i + 5] = 2 * axis - vals[i + 5]
            out.append("A" + " ".join(f(v) for v in vals))
        elif cmd == "Z":
            out.append("Z")

    for t in tokens:
        if t[0].isalpha():
            flush()
            cmd, nums = t[0], []
            if len(t) > 1:
                nums.append(t[1:])
        else:
            nums.append(t)
    flush()
    return " ".join(out)


def sym(*ds):
    """Returns each path and its mirror image."""
    out = []
    for d in ds:
        out += [d, mirror_x(d)]
    return out


# ---------------------------------------------------------------------------
# Drawings (viewBox 0 0 400 400). Each is a list of steps.
# ---------------------------------------------------------------------------

D = {}

D["cat"] = [
    [ellipse(200, 140, 72, 60)],
    sym("M140 108 L150 46 L186 88"),
    sym("M152 92 L157 64 L176 86"),
    [("fill", ellipse(175, 136, 8, 12)), ("fill", ellipse(225, 136, 8, 12))],
    [("fill", "M193 157 L207 157 L200 166 Z"), "M200 166 Q200 178 188 178", "M200 166 Q200 178 212 178"],
    sym("M160 158 L116 150", "M160 168 L114 172"),
    ["M150 188 C110 232 104 300 124 345 L276 345 C296 300 290 232 250 188"],
    ["M176 262 L173 345", "M224 262 L227 345", "M150 345 Q162 330 174 345", "M226 345 Q238 330 250 345"],
    ["M276 330 C330 330 346 282 322 252 C312 240 300 250 308 260"],
]

D["dog"] = [
    ["M120 150 C120 80 280 80 280 150 C285 230 250 290 200 290 C150 290 115 230 120 150 Z"],
    sym("M130 112 C90 100 70 150 80 210 C85 236 115 232 122 200"),
    [("fill", circle(165, 165, 10)), ("fill", circle(235, 165, 10)), "M215 140 C240 125 266 145 258 176"],
    [ellipse(200, 234, 48, 36), ("fill", "M182 212 Q200 202 218 212 Q212 228 200 230 Q188 228 182 212 Z")],
    ["M200 230 L200 246", "M200 246 Q185 262 172 250", "M200 246 Q215 262 228 250", "M190 256 Q200 282 210 256"],
]

D["fish"] = [
    ["M70 200 C110 120 250 110 300 200 C250 290 110 280 70 200 Z"],
    ["M300 200 L350 150 C340 185 340 215 350 250 Z"],
    [circle(115, 190, 12), ("fill", circle(117, 190, 6)), "M72 205 Q85 212 92 206"],
    ["M170 135 C190 95 240 100 256 150", "M190 265 C200 295 230 295 240 255", "M150 160 Q135 200 150 240"],
    ["M175 170 q15 15 0 30", "M175 200 q15 15 0 30", "M205 158 q15 15 0 30", "M205 188 q15 15 0 30",
     "M205 218 q15 15 0 30", "M235 170 q15 15 0 30", "M235 200 q15 15 0 30"],
    [circle(50, 140, 8), circle(38, 110, 5), circle(55, 84, 6)],
]

D["owl"] = [[
    "M140 120 C120 180 120 280 200 300 C280 280 280 180 260 120",
    "M140 120 L150 70 L180 95 Q200 88 220 95 L250 70 L260 120",
    circle(170, 140, 28), circle(230, 140, 28), ("fill", circle(173, 143, 10)), ("fill", circle(227, 143, 10)),
    ("fill", "M192 166 L208 166 L200 186 Z"),
    "M176 218 q8 10 16 0 q8 10 16 0 q8 10 16 0",
    "M168 243 q8 10 16 0 q8 10 16 0 q8 10 16 0 q8 10 16 0",
    "M180 268 q8 10 16 0 q8 10 16 0 q8 10 16 0",
    "M140 160 C110 200 120 250 150 275", "M260 160 C290 200 280 250 250 275",
    "M60 306 L340 306", "M300 306 Q320 286 342 290",
    "M174 300 L170 312 M180 300 L180 314 M186 300 L190 312",
    "M214 300 L210 312 M220 300 L220 314 M226 300 L230 312",
    *leaf(110, 306, 80, 270, 14),
]]

D["butterfly"] = [
    [ellipse(200, 212, 10, 70), circle(200, 128, 16)],
    sym("M194 116 Q180 80 165 74"), [circle(163, 72, 5), circle(237, 72, 5)],
    sym("M192 170 C140 90 60 90 70 160 C75 205 140 215 192 205"),
    sym("M192 216 C140 222 90 250 110 295 C130 330 175 300 194 252"),
    [circle(122, 152, 18), circle(278, 152, 18), circle(140, 272, 12), circle(260, 272, 12)],
]

D["car"] = [
    ["M50 262 L94 262 A39 39 0 0 1 172 262 L244 262 A39 39 0 0 1 322 262 L370 262 L370 225 C370 212 365 205 355 202 L330 195 "
     "L300 155 C292 145 285 140 270 140 L195 140 C185 140 178 142 170 150 L130 195 L80 200 C60 205 50 210 50 225 Z"],
    [circle(133, 264, 30), circle(283, 264, 30), circle(133, 264, 10), circle(283, 264, 10)],
    ["M146 192 L178 157 C182 153 186 152 192 152 L230 152 L230 192 Z",
     "M242 152 L268 152 C278 152 284 156 290 164 L310 192 L242 192 Z"],
    ["M236 196 L236 258", "M250 212 L266 212", "M352 212 L366 214", "M52 222 L62 222", "M80 232 L110 232"],
    ["M30 298 L380 298"],
]

D["bicycle"] = [[
    circle(115, 265, 64), circle(290, 265, 64), circle(115, 265, 6), circle(290, 265, 6),
    "M115 265 L180 265", "M180 265 L146 162", "M150 176 L255 176", "M180 265 L256 186",
    "M115 265 L152 180", "M255 176 L290 265", "M255 176 L249 146 L276 140",
    "M126 158 L166 158", circle(180, 265, 12), "M180 265 L194 288", "M186 290 L204 286",
]]

D["sailboat"] = [[
    "M80 270 L320 270 L280 318 L120 318 Z", "M200 270 L200 70",
    "M206 82 L206 256 L310 256 Z", "M194 96 L194 256 L100 256 Z", "M200 70 L230 80 L200 90",
    waves(40, 360, 342), circle(330, 92, 24), "M60 90 q10 -10 20 0 q10 -10 20 0",
]]

D["rocket"] = [[
    "M200 60 C250 100 260 180 250 280 L150 280 C140 180 150 100 200 60 Z",
    circle(200, 160, 25), circle(200, 160, 14), "M154 215 L246 215",
    "M150 230 L110 300 L155 280", "M250 230 L290 300 L245 280",
    "M170 280 L180 300 L220 300 L230 280", "M182 302 Q186 340 200 362 Q214 340 218 302",
    "M70 100 l0 20 m-10 -10 l20 0", "M320 140 l0 16 m-8 -8 l16 0", "M88 222 l0 14 m-7 -7 l14 0",
    circle(320, 260, 4), circle(90, 330, 3),
]]

D["mountains"] = [
    ["M20 330 L380 330"],
    ["M40 330 L170 120 L300 330"],
    ["M130 185 L150 205 L170 188 L190 208 L210 185"],
    ["M258 263 L300 190 L380 330"],
    [circle(300, 92, 28)],
    ["M60 330 L76 286 L92 330 Z", "M88 330 L102 298 L116 330 Z", "M80 92 q10 -10 20 0 q10 -10 20 0", "M112 122 q8 -8 16 0 q8 -8 16 0"],
]

D["tree"] = [[
    "M180 342 C186 290 186 252 175 222", "M220 342 C214 290 214 252 225 222",
    "M148 346 Q170 336 180 342", "M220 342 Q232 336 252 346", "M100 346 L300 346",
    "M190 262 Q170 242 150 236", "M210 256 Q235 242 250 232",
    "M175 222 C120 232 90 192 115 160 C90 120 130 80 165 95 C175 60 230 55 245 90 C290 80 320 120 295 156 C325 186 290 232 225 222",
    circle(150, 150, 8), circle(240, 128, 8), circle(270, 182, 8), circle(192, 118, 8), circle(205, 175, 8),
]]

D["island"] = [[
    waves(20, 380, 322, 10, 45), "M90 312 Q200 262 310 312",
    "M200 290 C205 234 215 184 235 142", "M216 290 C221 238 229 188 246 146",
    "M240 140 C210 110 170 115 145 140", "M240 140 C220 100 230 76 256 70", "M240 140 C270 110 310 115 332 140",
    "M240 140 C262 132 292 152 300 182", "M240 140 C220 142 190 160 186 192",
    circle(236, 152, 7), circle(250, 155, 7), circle(90, 90, 26),
]]

D["cactus"] = [[
    "M180 330 L180 142 C180 115 220 115 220 142 L220 330",
    "M180 250 C140 250 130 240 130 202 C130 186 150 186 150 202 C150 226 160 230 180 230",
    "M220 220 C260 220 270 210 270 172 C270 156 250 156 250 172 C250 196 240 200 220 200",
    "M200 134 L200 326", "M80 330 L320 330", "M100 330 q15 -20 30 0", "M272 330 q10 -12 20 0",
    circle(320, 80, 22), "M200 120 q-12 -16 0 -24 q12 8 0 24",
]]

D["tulip"] = [
    ["M200 190 C202 250 198 300 200 352"],
    ["M200 190 C160 185 145 140 155 90 L178 115 L200 80 L222 115 L245 90 C255 140 240 185 200 190 Z"],
    ["M178 115 C185 150 190 175 200 190", "M222 115 C215 150 210 175 200 190"],
    ["M200 332 C160 312 140 262 150 222 C175 246 195 282 200 322", "M200 302 C240 287 260 242 255 207 C230 232 208 262 201 292"],
]

D["rose"] = [[
    "M140 160 C130 110 180 85 210 95 C255 85 285 130 265 170 C250 205 220 215 200 212 C170 212 145 195 140 160 Z",
    "M200 120 C220 115 235 130 228 148 C220 165 195 165 188 150 C182 137 195 128 205 135",
    "M170 140 C170 175 200 190 230 178", "M160 125 C150 165 175 200 215 198",
    "M199 212 L198 352", "M198 212 q-25 5 -35 -10", "M202 212 q25 5 35 -10",
    *leaf(198, 282, 145, 238, 16), *leaf(199, 312, 252, 262, 16),
    "M198 252 l-9 -6", "M199 334 l9 -6",
]]


def sunflower():
    els = []
    for k in range(14):
        a = k * 2 * math.pi / 14
        tip = (200 + 112 * math.sin(a), 160 - 112 * math.cos(a))
        base = (200 + 40 * math.sin(a), 160 - 40 * math.cos(a))
        els += leaf(base[0], base[1], tip[0], tip[1], 17, rib=False)
    els.append(("white", circle(200, 160, 46)))
    els.append(circle(200, 160, 46))
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(60):
        r = 5.2 * math.sqrt(i + 0.5)
        if r > 40:
            break
        a = i * golden
        els.append(("fill", circle(200 + r * math.cos(a), 160 + r * math.sin(a), 2.2)))
    els += ["M200 272 C205 300 196 330 200 362"]
    els += leaf(201, 320, 255, 290, 16) + leaf(199, 340, 145, 312, 16)
    return [els]


D["sunflower"] = sunflower()

D["plant"] = [[
    "M130 266 L270 266 L270 284 L130 284 Z", "M140 284 L156 360 L244 360 L260 284",
    "M200 266 C195 222 170 192 142 172", "M200 266 C205 212 215 162 228 124", "M200 266 C215 232 250 216 284 206",
    *leaf(142, 172, 82, 118, 26), *leaf(228, 124, 256, 48, 24), *leaf(284, 206, 352, 168, 24),
    *leaf(200, 250, 140, 236, 14),
]]

D["cupcake"] = [
    ["M130 232 L150 340 L250 340 L270 232 Z"],
    ["M156 232 L166 340", "M180 232 L185 340", "M200 232 L200 340", "M220 232 L215 340", "M244 232 L234 340"],
    ["M120 234 C100 232 100 196 130 194 C125 162 165 152 180 166 C185 132 235 126 240 162 C260 152 296 172 280 196 C305 202 300 236 280 234 Z"],
    ["M140 206 C170 216 230 216 262 202", "M165 177 C185 187 215 187 235 174"],
    [circle(205, 120, 16), "M210 105 C215 86 225 76 240 70"],
    ["M150 222 l8 -4", "M252 216 l-6 -5", "M200 200 l0 -8", "M176 196 l6 4", "M230 190 l-7 3"],
]

D["icecream"] = [[
    "M140 200 L200 360 L260 200 Z",
    "M150 200 L212.9 325.7", "M180 200 L225.7 291.4", "M210 200 L238.6 257.1", "M240 200 L251.4 222.9",
    "M250 200 L187.1 325.7", "M220 200 L174.3 291.4", "M190 200 L161.4 257.1", "M160 200 L148.6 222.9",
    "M130 205 C120 170 150 150 175 158 C185 130 230 128 240 155 C265 145 285 175 270 205 C250 215 150 215 130 205 Z",
    "M160 211 q0 20 8 20 q8 0 8 -20", "M160 155 C150 120 180 100 200 105 C225 95 255 120 240 155", circle(200, 91, 12),
]]

D["pizza"] = [[
    "M200 350 L90 120 Q200 80 310 120 Z", "M90 120 Q200 80 310 120 L318 100 Q200 55 82 100 Z",
    circle(200, 142, 20), circle(160, 200, 17), circle(236, 214, 18), circle(200, 282, 14),
    circle(176, 152, 6), circle(222, 178, 6), circle(190, 238, 6), "M252 246 q5 25 12 15",
]]

D["apple"] = [[
    "M200 120 C170 95 100 100 100 180 C100 270 160 330 200 305 C240 330 300 270 300 180 C300 100 230 95 200 120 Z",
    "M200 120 C198 100 200 85 210 70", "M205 95 C220 70 260 70 270 85 C250 105 220 105 205 95 Z",
    "M205 95 Q240 88 268 85", "M140 160 C135 180 140 200 148 212",
]]

D["mika"] = [[
    "M140 170 C140 250 170 300 200 316 C230 300 260 250 260 170",
    "M180 306 L178 350 M220 306 L222 350", "M178 350 C140 356 112 370 96 398", "M222 350 C260 356 288 370 304 398",
    "M130 252 C104 180 110 95 200 85 C290 95 296 180 270 252 L256 252",
    "M136 176 C150 160 160 140 165 120 C172 140 185 160 200 168 C205 150 210 130 215 112 C222 140 240 160 264 176",
    "M140 178 L140 252 L130 252",
    "M150 205 C160 190 185 188 195 200", "M250 205 C240 190 215 188 205 200",
    ellipse(173, 216, 13, 17), ellipse(227, 216, 13, 17),
    ("fill", ellipse(174, 218, 6, 8)), ("fill", ellipse(226, 218, 6, 8)),
    ("white", circle(169, 210, 3.5)), ("white", circle(222, 210, 3.5)),
    "M163 233 Q173 237 184 233", "M216 233 Q227 237 237 233",
    "M155 182 Q170 176 185 180", "M245 182 Q230 176 215 180",
    "M200 246 l-3 7", "M190 272 Q200 279 210 272",
    "M150 248 l6 -6 M158 250 l6 -6", "M236 250 l6 -6 M244 248 l6 -6",
    star(244, 116, 13, 6),
]]

D["kenta"] = [[
    "M120 150 C120 80 280 80 280 150 C280 215 245 236 200 236 C155 236 120 215 120 150 Z",
    "M116 152 L110 110 L135 120 L140 80 L165 100 L185 64 L205 95 L235 70 L245 105 L275 95 L270 125 L290 140 L270 152",
    "M140 136 L160 118 L170 140 L190 114 L205 140 L225 118 L235 142 L255 125 L262 146",
    ("fill", ellipse(170, 176, 9, 14)), ("fill", ellipse(230, 176, 9, 14)),
    ("white", circle(167, 170, 3)), ("white", circle(227, 170, 3)),
    "M188 206 Q200 220 212 206 Z", "M150 196 l8 -5", "M242 196 l8 -5",
    "M165 236 L150 300 L250 300 L235 236", "M160 252 L130 286", "M240 252 L270 286",
    circle(126, 291, 9), circle(274, 291, 9), star(200, 266, 14, 6),
    "M155 300 L160 330 L195 330 L200 312 L205 330 L240 330 L245 300",
    "M172 330 L172 360", "M228 330 L228 360", "M155 366 Q172 350 188 366 Z", "M212 366 Q228 350 245 366 Z",
]]

D["neko"] = [[
    "M140 172 C140 248 168 294 200 306 C232 294 260 248 260 172",
    "M150 112 L140 50 L190 92", "M154 96 L149 66 L176 90", "M250 112 L260 50 L210 92", "M246 96 L251 66 L224 90",
    "M130 192 C115 120 150 86 200 88 C250 86 285 120 270 192 C280 262 290 320 300 370",
    "M130 192 C120 262 110 320 100 370", "M138 172 L155 130 L170 166 L185 118 L200 162 L215 118 L230 166 L245 130 L262 172",
    "M152 206 C162 192 186 190 194 202", "M248 206 C238 192 214 190 206 202",
    ellipse(173, 218, 13, 16), ellipse(227, 218, 13, 16), ("fill", ellipse(173, 219, 3, 11)), ("fill", ellipse(227, 219, 3, 11)),
    "M190 266 Q195 273 200 266 Q205 273 210 266", "M198 248 l2 4",
    "M146 250 L162 248", "M146 259 L162 259", "M254 250 L238 248", "M254 259 L238 259",
    "M182 300 L180 334 M218 300 L220 334", "M174 334 Q200 346 226 334", circle(200, 351, 9), "M193 351 L207 351",
]]

D["face_guide"] = [
    [ellipse(200, 200, 95, 130)],
    ["M200 70 L200 330", "M105 200 L295 200", "M140 256 L260 256", "M160 286 L240 286"],
    ["M140 200 Q160 185 180 200 Q160 212 140 200 Z", "M220 200 Q240 185 260 200 Q240 212 220 200 Z",
     ("fill", circle(160, 199, 7)), ("fill", circle(240, 199, 7))],
    ["M200 206 L192 250 Q200 258 210 252", "M188 252 q-6 0 -6 -6", "M212 252 q6 0 6 -6"],
    ["M172 286 Q200 278 228 286 Q200 302 172 286 Z"],
    ["M135 182 Q158 170 182 180", "M218 180 Q242 170 265 182",
     "M105 200 C90 195 88 240 108 250", "M295 200 C310 195 312 240 292 250"],
    ["M160 318 L160 372 M240 318 L240 372", "M106 196 C94 100 160 64 200 66 C240 64 306 100 294 196",
     "M118 150 C140 112 180 102 200 102 C220 102 260 112 282 150"],
]

D["portrait"] = [[
    "M145 180 C145 260 175 310 200 316 C225 310 255 260 255 180",
    "M145 190 C130 110 170 75 210 80 C260 85 275 140 255 200",
    "M145 190 C120 250 140 300 115 360", "M255 200 C280 260 260 300 290 360",
    "M210 80 C190 110 170 130 150 160", "M215 85 C230 110 245 140 252 170",
    "M163 206 Q175 214 187 206", "M213 206 Q225 214 237 206", "M165 210 l-4 4 M171 212 l-2 5", "M229 212 l2 5 M235 210 l4 4",
    "M160 190 Q175 183 190 188", "M210 188 Q225 183 240 190", "M200 216 L195 246 Q200 251 206 248",
    "M185 272 Q193 266 200 270 Q207 266 215 272 Q200 284 185 272 Z",
    "M180 308 L178 346 C150 352 120 362 100 390", "M220 308 L222 346 C250 352 280 362 300 390", circle(148, 242, 5), circle(252, 242, 5),
]]

D["profile"] = [[
    "M230 82 C170 82 140 120 140 170 L124 214 L140 220 C138 234 140 244 146 250 C140 258 145 268 152 270 C150 290 165 300 190 300 L195 342",
    "M230 82 C290 86 310 150 290 210 C280 240 260 260 255 280 L258 342",
    "M158 172 Q168 166 178 172", ("fill", circle(167, 173, 4)), "M152 157 Q165 149 182 155",
    "M236 176 C256 166 262 200 240 210", "M140 150 C150 110 190 96 230 96",
    "M290 152 C330 162 340 220 320 262 C310 232 300 202 292 186", "M150 196 l-6 10",
]]

D["house"] = [
    ["M100 200 L100 340 L300 340 L300 200"],
    ["M80 210 L200 100 L320 210 Z"],
    ["M175 340 L175 272 Q200 252 225 272 L225 340", circle(215, 306, 4)],
    ["M120 226 h40 v40 h-40 Z", "M140 226 v40", "M120 246 h40", "M240 226 h40 v40 h-40 Z", "M260 226 v40", "M240 246 h40"],
    ["M250 145 L250 110 L275 110 L275 168", "M262 96 q-10 -12 0 -24 q10 -12 0 -24"],
    ["M40 340 L360 340", "M188 340 L168 382", "M212 340 L232 382"],
]

D["lighthouse"] = [[
    "M165 320 L180 140 L220 140 L235 320", "M175 200 L225 200", "M170 260 L230 260",
    "M170 140 L230 140 L230 128 L170 128 Z", "M182 128 L182 100 L218 100 L218 128", "M175 100 L200 74 L225 100 Z", "M200 100 L200 128",
    "M182 110 L80 84", "M182 120 L80 142", "M218 110 L320 84", "M218 120 L320 142",
    "M192 320 L192 290 Q200 282 208 290 L208 320",
    "M120 320 C130 300 160 305 165 320", "M235 320 C245 302 275 302 285 320", "M90 320 L310 320", waves(40, 360, 350),
]]

D["teapot"] = [[
    "M120 200 C110 280 150 320 200 320 C250 320 290 280 280 200 Z", "M135 200 C140 174 260 174 265 200", circle(200, 165, 10),
    "M122 232 C90 226 80 202 70 176 L86 170 C96 196 106 206 126 256",
    "M278 216 C332 210 332 292 270 286", "M280 232 C310 232 310 270 276 268", "M150 320 L156 332 L244 332 L250 320",
    "M200 270 C175 252 175 232 190 230 C196 230 200 236 200 240 C200 236 204 230 210 230 C225 232 225 252 200 270 Z",
    "M72 158 q-10 -15 0 -30 q10 -15 0 -30",
]]

D["castle"] = [[
    "M70 340 L70 140 L130 140 L130 340", "M270 340 L270 140 L330 140 L330 340",
    "M62 140 L100 80 L138 140 Z", "M262 140 L300 80 L338 140 Z", "M100 80 L100 56 L122 64 L100 72", "M300 80 L300 56 L322 64 L300 72",
    "M170 220 L170 120 L230 120 L230 220", "M170 120 V106 H182 V120 H194 V106 H206 V120 H218 V106 H230 V120",
    "M130 340 L130 206 H143 V220 H156 V206 H170", "M230 206 H243 V220 H256 V206 H270 L270 340",
    "M170 340 L170 290 Q200 256 230 290 L230 340", "M185 280 L185 340 M200 272 L200 340 M215 280 L215 340 M170 306 L230 306",
    "M95 200 L95 180 Q100 172 105 180 L105 200 Z", "M295 200 L295 180 Q300 172 305 180 L305 200 Z", circle(200, 160, 12),
    "M40 340 L360 340",
]]

D["heart"] = [[
    "M200 330 C120 270 70 220 70 160 C70 115 105 85 145 85 C170 85 190 100 200 120 C210 100 230 85 255 85 C295 85 330 115 330 160 C330 220 280 270 200 330 Z",
    "M110 150 C112 130 125 118 140 115",
]]

D["star"] = [[star(200, 210, 145, 62), "M150 190 l0 6", "M250 190 l0 6", "M176 236 Q200 254 224 236"]]


def sun():
    els = [circle(200, 200, 74)]
    for k in range(12):
        a = k * math.pi / 6
        x0, y0 = 200 + 94 * math.cos(a), 200 + 94 * math.sin(a)
        x1, y1 = 200 + 132 * math.cos(a), 200 + 132 * math.sin(a)
        els.append(f"M{f(x0)} {f(y0)} L{f(x1)} {f(y1)}")
    els += [("fill", ellipse(175, 185, 7, 11)), ("fill", ellipse(225, 185, 7, 11)), "M166 222 Q200 252 234 222", circle(156, 214, 8), circle(244, 214, 8)]
    return [els]


D["sun"] = sun()

D["cloud"] = [[
    "M110 220 C80 220 70 180 100 170 C95 130 150 115 170 140 C185 100 260 100 265 150 C300 145 320 190 290 220 Z",
    teardrop(130, 252), teardrop(175, 272), teardrop(222, 252), teardrop(266, 272), teardrop(152, 306), teardrop(242, 306),
]]

D["balloon"] = [[
    "M200 250 C140 250 120 190 120 160 C120 110 160 80 200 80 C240 80 280 110 280 160 C280 190 260 250 200 250 Z",
    "M192 250 L208 250 L200 262 Z", "M200 262 C185 290 215 320 200 362", "M150 140 C152 120 165 108 180 104",
]]


def mandala():
    els = [circle(200, 200, 160), circle(200, 200, 122), circle(200, 200, 80), circle(200, 200, 38), circle(200, 200, 14)]
    for k in range(8):
        a = k * math.pi / 4
        b = (200 + 40 * math.cos(a), 200 + 40 * math.sin(a))
        t = (200 + 78 * math.cos(a), 200 + 78 * math.sin(a))
        els += leaf(b[0], b[1], t[0], t[1], 13, rib=False)
    for k in range(16):
        a0, a1 = k * math.pi / 8, (k + 1) * math.pi / 8
        p0 = (200 + 80 * math.cos(a0), 200 + 80 * math.sin(a0))
        p1 = (200 + 80 * math.cos(a1), 200 + 80 * math.sin(a1))
        am = (a0 + a1) / 2
        c = (200 + 122 * math.cos(am), 200 + 122 * math.sin(am))
        els.append(f"M{f(p0[0])} {f(p0[1])} Q{f(c[0])} {f(c[1])} {f(p1[0])} {f(p1[1])}")
    for k in range(12):
        a = k * math.pi / 6 + math.pi / 12
        b = (200 + 122 * math.cos(a), 200 + 122 * math.sin(a))
        t = (200 + 158 * math.cos(a), 200 + 158 * math.sin(a))
        els += leaf(b[0], b[1], t[0], t[1], 12, rib=True)
    for k in range(12):
        a = k * math.pi / 6
        els.append(circle(200 + 141 * math.cos(a), 200 + 141 * math.sin(a), 6))
    return [els]


D["mandala"] = mandala()

D["butterfly_color"] = [[
    ellipse(200, 212, 12, 72), circle(200, 128, 17),
    *sym("M194 116 Q180 80 165 74"), circle(163, 72, 6), circle(237, 72, 6),
    *sym("M190 170 C140 88 56 88 68 160 C74 206 140 216 190 206 Z"),
    *sym("M190 218 C140 224 88 252 108 298 C128 334 176 302 192 252 Z"),
    *sym("M188 182 C160 150 118 128 96 146 C110 176 150 186 188 192"),
    circle(110, 132, 14), circle(290, 132, 14), circle(140, 276, 14), circle(260, 276, 14),
    *sym("M188 240 C160 246 130 262 124 284"),
]]

D["fish_color"] = [[
    "M60 200 C100 112 260 104 310 200 C260 296 100 288 60 200 Z", "M310 200 L362 142 C350 182 350 218 362 258 Z",
    "M140 128 C120 170 120 230 140 272", "M190 116 C170 170 170 230 190 284", "M240 122 C220 170 220 230 240 278",
    circle(100, 188, 14), circle(102, 188, 6), "M164 124 C186 78 240 84 256 134 Z", "M176 278 C188 312 222 312 236 274 Z",
    circle(40, 130, 9), circle(30, 96, 6), circle(52, 68, 7),
]]


def garden():
    els = ["M20 360 L380 360", "M20 360 C60 330 90 345 120 330 C160 345 200 325 240 340 C280 325 330 345 380 330 L380 360 Z"]
    for cx, cy, r, n in [(100, 214, 20, 7), (210, 150, 24, 8), (312, 226, 18, 6)]:
        els.append(f"M{f(cx)} {f(cy + r + 38)} C{f(cx + 6)} 300 {f(cx - 6)} 320 {f(cx)} 340")
        els += leaf(cx, 322, cx + 42, 296, 12)
        for k in range(n):
            a = k * 2 * math.pi / n
            b = (cx + r * math.cos(a), cy + r * math.sin(a))
            t = (cx + (r + 40) * math.cos(a), cy + (r + 40) * math.sin(a))
            els += leaf(b[0], b[1], t[0], t[1], min(15, (r + 14) * math.sin(math.pi / n)), rib=False)
        els.append(circle(cx, cy, r))
    els += [circle(340, 70, 28), "M40 80 q10 -10 20 0 q10 -10 20 0"]
    return [els]


D["garden"] = garden()


def hex_pattern():
    els = ["M30 30 L370 30 L370 370 L30 370 Z"]
    r = 32
    h = r * math.sqrt(3)
    for col in range(-1, 10):
        for row in range(-1, 9):
            x = 52 + col * 1.5 * r
            y = 52 + row * h + (h / 2 if col % 2 else 0)
            pts = [(x + r * math.cos(k * math.pi / 3), y + r * math.sin(k * math.pi / 3)) for k in range(6)]
            if all(30 <= px <= 370 and 30 <= py <= 370 for px, py in pts):
                els.append("M" + " L".join(f"{f(px)} {f(py)}" for px, py in pts) + " Z")
                els.append(circle(x, y, 13))
    return [els]


D["hexagons"] = hex_pattern()

# ---------------------------------------------------------------------------
# Library manifest
# ---------------------------------------------------------------------------

def T(en, ar, he):
    return {"en": en, "ar": ar, "he": he}


REFS = [
    # id, category, difficulty, style, title, featured, tags, stroke width
    ("cat", "animals", "easy", "cartoon", T("Sitting cat", "قطة جالسة", "חתול יושב"), True, ["cat", "kitten", "pet"], 6),
    ("dog", "animals", "easy", "cartoon", T("Happy puppy", "جرو سعيد", "גור שמח"), False, ["dog", "puppy", "pet"], 6),
    ("fish", "animals", "easy", "cartoon", T("Little fish", "سمكة صغيرة", "דג קטן"), False, ["fish", "sea"], 6),
    ("owl", "animals", "medium", "line", T("Owl on a branch", "بومة على غصن", "ינשוף על ענף"), False, ["owl", "bird"], 5),
    ("butterfly", "animals", "easy", "line", T("Butterfly", "فراشة", "פרפר"), False, ["butterfly", "insect"], 5),
    ("car", "vehicles", "medium", "line", T("Family car", "سيارة عائلية", "מכונית משפחתית"), True, ["car", "auto"], 6),
    ("bicycle", "vehicles", "medium", "line", T("Bicycle", "دراجة هوائية", "אופניים"), False, ["bike", "bicycle"], 5),
    ("sailboat", "vehicles", "easy", "line", T("Sailboat", "قارب شراعي", "סירת מפרש"), False, ["boat", "sea"], 5),
    ("rocket", "vehicles", "easy", "cartoon", T("Rocket", "صاروخ", "טיל"), False, ["rocket", "space"], 6),
    ("mountains", "nature", "easy", "line", T("Mountain view", "منظر جبلي", "נוף הרים"), True, ["mountain", "landscape"], 5),
    ("tree", "nature", "easy", "line", T("Apple tree", "شجرة تفاح", "עץ תפוח"), False, ["tree"], 5),
    ("island", "nature", "easy", "line", T("Palm island", "جزيرة النخيل", "אי דקלים"), False, ["beach", "palm", "sea"], 5),
    ("cactus", "nature", "easy", "cartoon", T("Desert cactus", "صبّار الصحراء", "קקטוס במדבר"), False, ["cactus", "desert"], 5),
    ("tulip", "flowers", "easy", "line", T("Tulip", "زهرة التوليب", "צבעוני"), False, ["flower", "tulip"], 5),
    ("rose", "flowers", "medium", "line", T("Rose", "وردة", "ורד"), True, ["flower", "rose"], 5),
    ("sunflower", "flowers", "medium", "detailed", T("Sunflower", "زهرة عباد الشمس", "חמנייה"), False, ["flower", "sunflower"], 4),
    ("plant", "flowers", "easy", "line", T("Potted plant", "نبتة في أصيص", "עציץ"), False, ["plant", "leaf"], 5),
    ("cupcake", "food", "easy", "cartoon", T("Cupcake", "كب كيك", "קאפקייק"), True, ["cake", "sweet"], 5),
    ("icecream", "food", "easy", "cartoon", T("Ice cream cone", "قرن آيس كريم", "גביע גלידה"), False, ["ice cream", "sweet"], 5),
    ("pizza", "food", "easy", "cartoon", T("Pizza slice", "شريحة بيتزا", "משולש פיצה"), False, ["pizza"], 5),
    ("apple", "food", "easy", "line", T("Apple", "تفاحة", "תפוח"), False, ["fruit", "apple"], 6),
    ("mika", "anime", "medium", "cartoon", T("Mika (original character)", "ميكا (شخصية أصلية)", "מיקה (דמות מקורית)"), True, ["anime", "girl", "manga"], 4),
    ("kenta", "anime", "easy", "cartoon", T("Kenta, chibi style", "كينتا بأسلوب تشيبي", "קנטה בסגנון צ׳יבי"), False, ["anime", "chibi", "boy"], 4),
    ("neko", "anime", "hard", "cartoon", T("Neko-chan (original character)", "نيكو-تشان (شخصية أصلية)", "נקו-צ׳אן (דמות מקורית)"), False, ["anime", "cat ears"], 4),
    ("face_guide", "people", "medium", "detailed", T("Face proportions guide", "دليل نِسَب الوجه", "מדריך פרופורציות פנים"), False, ["face", "portrait", "guide"], 4),
    ("portrait", "people", "medium", "line", T("Calm portrait", "بورتريه هادئ", "דיוקן רגוע"), False, ["woman", "portrait"], 4),
    ("profile", "people", "hard", "line", T("Side profile", "وجه جانبي", "פרופיל צד"), False, ["profile", "face"], 4),
    ("house", "objects", "easy", "line", T("Cozy house", "بيت دافئ", "בית חמים"), True, ["house", "home"], 5),
    ("lighthouse", "objects", "medium", "line", T("Lighthouse", "منارة", "מגדלור"), False, ["lighthouse", "sea"], 5),
    ("teapot", "objects", "easy", "line", T("Teapot", "إبريق شاي", "קומקום תה"), False, ["tea", "teapot"], 5),
    ("castle", "objects", "hard", "line", T("Castle", "قلعة", "טירה"), False, ["castle", "building"], 5),
    ("heart", "simple", "easy", "cartoon", T("Heart", "قلب", "לב"), False, ["heart", "love"], 7),
    ("star", "simple", "easy", "cartoon", T("Smiling star", "نجمة مبتسمة", "כוכב מחייך"), False, ["star"], 7),
    ("sun", "simple", "easy", "cartoon", T("Happy sun", "شمس سعيدة", "שמש שמחה"), False, ["sun"], 6),
    ("cloud", "simple", "easy", "cartoon", T("Rain cloud", "غيمة ممطرة", "ענן גשם"), False, ["cloud", "rain"], 6),
    ("balloon", "simple", "easy", "cartoon", T("Balloon", "بالون", "בלון"), False, ["balloon"], 6),
    ("mandala", "coloring", "hard", "pattern", T("Flower mandala", "ماندالا زهرية", "מנדלה פרחונית"), True, ["mandala", "pattern"], 4),
    ("butterfly_color", "coloring", "easy", "cartoon", T("Butterfly to color", "فراشة للتلوين", "פרפר לצביעה"), False, ["butterfly"], 6),
    ("fish_color", "coloring", "easy", "cartoon", T("Striped fish to color", "سمكة مخططة للتلوين", "דג מפוספס לצביעה"), False, ["fish"], 6),
    ("garden", "coloring", "medium", "cartoon", T("Flower garden", "حديقة زهور", "גן פרחים"), False, ["flowers", "garden"], 5),
    ("hexagons", "coloring", "medium", "pattern", T("Honeycomb pattern", "نقش خلية النحل", "דוגמת כוורת"), False, ["pattern", "geometric"], 4),
]


def svg_for(steps, stroke):
    parts = []
    for step in steps:
        for el in step:
            if isinstance(el, tuple):
                kind, d = el
                color = INK if kind == "fill" else "#FFFFFF"
                parts.append(f'<path d="{d}" fill="{color}" stroke="none"/>')
            else:
                parts.append(f'<path d="{el}"/>')
    body = "\n    ".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">\n'
            f'  <g fill="none" stroke="{INK}" stroke-width="{stroke}" stroke-linecap="round" stroke-linejoin="round">\n'
            f'    {body}\n  </g>\n</svg>\n')


# ---------------------------------------------------------------------------
# Lessons
# ---------------------------------------------------------------------------

M = {
    "pencil": T("HB or 2B pencil", "قلم رصاص HB أو 2B", "עיפרון HB או 2B"),
    "eraser": T("Soft eraser", "ممحاة ناعمة", "מחק רך"),
    "paper": T("Plain paper", "ورق أبيض", "דף לבן"),
    "pen": T("Black fineliner (optional)", "قلم حبر أسود رفيع (اختياري)", "טוש שחור דק (לא חובה)"),
    "colors": T("Colored pencils or markers (optional)", "أقلام تلوين خشبية أو ماركر (اختياري)", "עפרונות צבעוניים או טושים (לא חובה)"),
    "ruler": T("Ruler (optional)", "مسطرة (اختيارية)", "סרגל (לא חובה)"),
}

LESSONS = [
    ("cat-face", "cat", "animals", "easy", 10, T("Cute sitting cat", "قطة لطيفة جالسة", "חתול חמוד יושב"), ["pencil", "eraser", "paper", "pen"], [
        T("Draw a wide oval for the head, a bit wider than it is tall.", "ارسم شكلًا بيضاويًا عريضًا للرأس، عرضه أكبر قليلًا من ارتفاعه.", "ציירו אליפסה רחבה לראש, מעט רחבה יותר מגובהה."),
        T("Add two pointed ears on top of the head.", "أضف أذنين مدببتين أعلى الرأس.", "הוסיפו שתי אוזניים מחודדות בראש הראש."),
        T("Draw a smaller triangle inside each ear.", "ارسم مثلثًا أصغر داخل كل أذن.", "ציירו משולש קטן יותר בתוך כל אוזן."),
        T("Place two tall oval eyes and fill them in.", "ضع عينين بيضاويتين طويلتين ولوّنهما بالكامل.", "מקמו שתי עיניים אליפטיות גבוהות ומלאו אותן."),
        T("Add a small triangle nose and a mouth shaped like a ‘w’.", "أضف أنفًا مثلثًا صغيرًا وفمًا على شكل حرف w.", "הוסיפו אף משולש קטן ופה בצורת האות w."),
        T("Draw three whiskers on each side — two is fine too!", "ارسم شاربين أو ثلاثة على كل جانب.", "ציירו שניים או שלושה שפמים בכל צד."),
        T("Draw the body like a soft pear shape under the head.", "ارسم الجسم تحت الرأس على شكل كمثرى ناعمة.", "ציירו את הגוף מתחת לראש בצורת אגס רך."),
        T("Add the front legs and little rounded paws.", "أضف الساقين الأماميتين ومخالب صغيرة مستديرة.", "הוסיפו את הרגליים הקדמיות וכפות מעוגלות קטנות."),
        T("Finish with a curly tail wrapping around the side.", "اختم بذيل ملتف حول الجانب.", "סיימו בזנב מתולתל שמתעקל לצד."),
    ]),
    ("tulip", "tulip", "flowers", "easy", 8, T("Simple tulip", "زهرة توليب بسيطة", "צבעוני פשוט"), ["pencil", "eraser", "paper", "colors"], [
        T("Draw a long, gently curved line for the stem.", "ارسم خطًا طويلًا منحنيًا قليلًا للساق.", "ציירו קו ארוך ומעט מעוקל לגבעול."),
        T("Draw the cup-shaped flower with three pointed tips on top.", "ارسم الزهرة على شكل كوب بثلاثة أطراف مدببة في الأعلى.", "ציירו את הפרח בצורת גביע עם שלושה קצוות מחודדים למעלה."),
        T("Add two curved lines inside to show the petals overlapping.", "أضف خطين منحنيين في الداخل لإظهار تداخل البتلات.", "הוסיפו שני קווים מעוקלים בפנים כדי להראות עלי כותרת חופפים."),
        T("Finish with two long leaves curling out from the stem.", "اختم بورقتين طويلتين تنحنيان من الساق.", "סיימו בשני עלים ארוכים שמתעקלים מהגבעול."),
    ]),
    ("house", "house", "objects", "easy", 10, T("Little house", "بيت صغير", "בית קטן"), ["pencil", "eraser", "paper", "ruler"], [
        T("Draw a large square for the walls (the top stays open).", "ارسم مربعًا كبيرًا للجدران واترك أعلاه مفتوحًا.", "ציירו ריבוע גדול לקירות (החלק העליון נשאר פתוח)."),
        T("Add a triangle roof that hangs a little past the walls.", "أضف سقفًا مثلثًا يمتد قليلًا خارج الجدران.", "הוסיפו גג משולש שבולט מעט מעבר לקירות."),
        T("Draw a door with a rounded top and a small knob.", "ارسم بابًا بقمة مستديرة ومقبضًا صغيرًا.", "ציירו דלת עם חלק עליון מעוגל וידית קטנה."),
        T("Add two square windows with a cross in each.", "أضف نافذتين مربعتين في كل منهما صليب.", "הוסיפו שני חלונות מרובעים עם צלב בכל אחד."),
        T("Draw a chimney on the roof and a curly line of smoke.", "ارسم مدخنة على السقف وخطًا متموجًا للدخان.", "ציירו ארובה על הגג וקו עשן מסולסל."),
        T("Finish with the ground and a path to the door.", "اختم بالأرض وممر يؤدي إلى الباب.", "סיימו עם הקרקע ושביל אל הדלת."),
    ]),
    ("fish", "fish", "animals", "easy", 8, T("Cartoon fish", "سمكة كرتونية", "דג מצויר"), ["pencil", "eraser", "paper", "colors"], [
        T("Draw a lemon shape for the body.", "ارسم شكل ليمونة لجسم السمكة.", "ציירו צורת לימון לגוף."),
        T("Add a triangle tail with a curved edge.", "أضف ذيلًا مثلثًا بحافة منحنية.", "הוסיפו זנב משולש עם קצה מעוקל."),
        T("Draw the eye with a filled pupil and a little smile.", "ارسم العين مع بؤبؤ ممتلئ وابتسامة صغيرة.", "ציירו את העין עם אישון מלא וחיוך קטן."),
        T("Add fins on top and bottom, and a curved gill line.", "أضف زعانف في الأعلى والأسفل وخطًا منحنيًا للخياشيم.", "הוסיפו סנפירים למעלה ולמטה וקו זימים מעוקל."),
        T("Draw small ‘c’ shapes for scales.", "ارسم أشكالًا صغيرة تشبه حرف c للحراشف.", "ציירו צורות קטנות כמו האות c לקשקשים."),
        T("Finish with a few bubbles.", "اختم ببعض الفقاعات.", "סיימו בכמה בועות."),
    ]),
    ("mountains", "mountains", "nature", "medium", 15, T("Mountain landscape", "منظر جبلي", "נוף הררי"), ["pencil", "eraser", "paper", "colors"], [
        T("Draw a straight line across the page for the ground.", "ارسم خطًا مستقيمًا عبر الصفحة للأرض.", "ציירו קו ישר לרוחב הדף לקרקע."),
        T("Draw a big triangle mountain rising from the ground.", "ارسم جبلًا مثلثًا كبيرًا يرتفع من الأرض.", "ציירו הר משולש גדול שעולה מהקרקע."),
        T("Add a zig-zag line near the top for the snow cap.", "أضف خطًا متعرجًا قرب القمة لغطاء الثلج.", "הוסיפו קו זיגזג ליד הפסגה לכיפת השלג."),
        T("Draw a smaller mountain peeking from behind.", "ارسم جبلًا أصغر يطل من الخلف.", "ציירו הר קטן יותר שמציץ מאחור."),
        T("Add a round sun in the sky.", "أضف شمسًا مستديرة في السماء.", "הוסיפו שמש עגולה בשמיים."),
        T("Finish with small pine trees and a couple of birds.", "اختم بأشجار صنوبر صغيرة وبعض الطيور.", "סיימו בעצי אורן קטנים וכמה ציפורים."),
    ]),
    ("cupcake", "cupcake", "food", "easy", 10, T("Sweet cupcake", "كب كيك حلو", "קאפקייק מתוק"), ["pencil", "eraser", "paper", "colors"], [
        T("Draw the paper cup: wider at the top, narrower at the bottom.", "ارسم الكوب الورقي: أعرض من الأعلى وأضيق من الأسفل.", "ציירו את עטיפת הנייר: רחבה למעלה וצרה למטה."),
        T("Add vertical lines for the folds in the paper.", "أضف خطوطًا عمودية لثنيات الورق.", "הוסיפו קווים אנכיים לקפלי הנייר."),
        T("Draw the fluffy frosting with bumpy curves.", "ارسم الكريمة المنتفخة بمنحنيات متموجة.", "ציירו את הקצפת האוורירית בקימורים גליים."),
        T("Add two curved lines to show the swirl.", "أضف خطين منحنيين لإظهار الالتفاف.", "הוסיפו שני קווים מעוקלים להראות את הסלסול."),
        T("Put a cherry with a stem on top.", "ضع حبة كرز مع عنقها في الأعلى.", "שימו דובדבן עם גבעול למעלה."),
        T("Finish with tiny sprinkles.", "اختم برشّات صغيرة من الحلوى الملونة.", "סיימו בסוכריות צבעוניות קטנות."),
    ]),
    ("car", "car", "vehicles", "medium", 20, T("Car from the side", "سيارة من الجانب", "מכונית מהצד"), ["pencil", "eraser", "paper", "ruler", "pen"], [
        T("Draw the body outline, leaving two round arches for the wheels.", "ارسم الإطار الخارجي للسيارة مع ترك قوسين للعجلات.", "ציירו את קו המתאר של הגוף והשאירו שתי קשתות לגלגלים."),
        T("Draw the wheels inside the arches, with a small circle in each.", "ارسم العجلات داخل الأقواس مع دائرة صغيرة في كل منها.", "ציירו את הגלגלים בתוך הקשתות עם עיגול קטן בכל אחד."),
        T("Add the two side windows.", "أضف النافذتين الجانبيتين.", "הוסיפו את שני החלונות הצדדיים."),
        T("Draw the door line, handle and lights.", "ارسم خط الباب والمقبض والأضواء.", "ציירו את קו הדלת, הידית והפנסים."),
        T("Finish with a road line under the wheels.", "اختم بخط الطريق تحت العجلات.", "סיימו בקו כביש מתחת לגלגלים."),
    ]),
    ("face", "face_guide", "people", "medium", 20, T("Face proportions", "نِسَب الوجه", "פרופורציות הפנים"), ["pencil", "eraser", "paper"], [
        T("Draw a tall oval for the head.", "ارسم شكلًا بيضاويًا طويلًا للرأس.", "ציירו אליפסה גבוהה לראש."),
        T("Lightly draw guide lines: a center line, eyes halfway down, then nose and mouth lines.", "ارسم بخفة خطوطًا إرشادية: خط في المنتصف، والعينان في منتصف الرأس، ثم خطا الأنف والفم.", "ציירו בעדינות קווי עזר: קו אמצע, העיניים באמצע הגובה, ואז קווי האף והפה."),
        T("Draw almond-shaped eyes on the eye line, one eye-width apart.", "ارسم عينين لوزيتين على خط العينين، والمسافة بينهما بعرض عين.", "ציירו עיניים בצורת שקד על קו העיניים, במרחק של עין אחת ביניהן."),
        T("Draw the nose ending on the nose line.", "ارسم الأنف لينتهي عند خط الأنف.", "ציירו את האף כך שיסתיים על קו האף."),
        T("Draw the lips on the mouth line.", "ارسم الشفتين على خط الفم.", "ציירו את השפתיים על קו הפה."),
        T("Add eyebrows above the eyes and ears between the eye and nose lines.", "أضف الحاجبين فوق العينين والأذنين بين خطي العينين والأنف.", "הוסיפו גבות מעל העיניים ואוזניים בין קו העיניים לקו האף."),
        T("Finish with the hairline and neck. Erase the guide lines gently.", "اختم بخط الشعر والرقبة، ثم امحُ الخطوط الإرشادية برفق.", "סיימו בקו השיער והצוואר ומחקו בעדינות את קווי העזר."),
    ]),
]

ANIME_LESSON_STEPS = [
    ["M140 170 C140 250 170 300 200 316 C230 300 260 250 260 170"],
    ["M130 252 C104 180 110 95 200 85 C290 95 296 180 270 252 L256 252",
     "M136 176 C150 160 160 140 165 120 C172 140 185 160 200 168 C205 150 210 130 215 112 C222 140 240 160 264 176", "M140 178 L140 252 L130 252"],
    ["M150 205 C160 190 185 188 195 200", "M250 205 C240 190 215 188 205 200", ellipse(173, 216, 13, 17), ellipse(227, 216, 13, 17),
     ("fill", ellipse(174, 218, 6, 8)), ("fill", ellipse(226, 218, 6, 8)), "M163 233 Q173 237 184 233", "M216 233 Q227 237 237 233"],
    ["M155 182 Q170 176 185 180", "M245 182 Q230 176 215 180", "M200 246 l-3 7", "M190 272 Q200 279 210 272"],
    ["M180 306 L178 350 M220 306 L222 350", "M178 350 C140 356 112 370 96 398", "M222 350 C260 356 288 370 304 398",
     "M150 248 l6 -6 M158 250 l6 -6", "M236 250 l6 -6 M244 248 l6 -6", star(244, 116, 13, 6)],
]
D["anime_lesson"] = ANIME_LESSON_STEPS
LESSONS.append(("anime-face", "anime_lesson", "anime", "medium", 20, T("Anime-style face", "وجه بأسلوب الأنمي", "פנים בסגנון אנימה"), ["pencil", "eraser", "paper", "pen"], [
    T("Draw the face shape: rounded cheeks narrowing to a small pointed chin.", "ارسم شكل الوجه: وجنتان مستديرتان تضيقان نحو ذقن صغير مدبب.", "ציירו את צורת הפנים: לחיים מעוגלות שמצטמצמות לסנטר קטן ומחודד."),
    T("Add the bob haircut and the bangs over the forehead.", "أضف قصة الشعر القصيرة والغرة فوق الجبين.", "הוסיפו תספורת קארה ופוני מעל המצח."),
    T("Draw big eyes low on the face, with a thick upper lash line.", "ارسم عينين كبيرتين في الجزء السفلي من الوجه مع رموش علوية سميكة.", "ציירו עיניים גדולות נמוך בפנים, עם קו ריסים עליון עבה."),
    T("Add thin eyebrows, a tiny nose and a small smile.", "أضف حاجبين رفيعين وأنفًا صغيرًا وابتسامة صغيرة.", "הוסיפו גבות דקות, אף זעיר וחיוך קטן."),
    T("Finish with the neck, shoulders, blush marks and a hair clip.", "اختم بالرقبة والكتفين وخطوط الخجل ومشبك الشعر.", "סיימו בצוואר, בכתפיים, בסומק ובסיכת שיער."),
]))


def lesson_json(lid, drawing, subject, diff, minutes, title, mats, texts):
    steps = D[drawing]
    assert len(steps) == len(texts), (lid, len(steps), len(texts))
    out_steps = []
    for st, tx in zip(steps, texts):
        paths = [e for e in st if isinstance(e, str)]
        fills = [e[1] for e in st if isinstance(e, tuple) and e[0] == "fill"]
        out_steps.append({"paths": paths, "fills": fills, "text": tx})
    return {"id": lid, "title": title, "subject": subject, "difficulty": diff, "minutes": minutes,
            "materials": [M[m] for m in mats], "width": 400, "height": 400, "stroke": 5, "steps": out_steps}


def main():
    refs = []
    for rid, cat, diff, style, title, featured, tags, stroke in REFS:
        d = os.path.join(ROOT, "library", cat)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, f"{rid}.svg"), "w", encoding="utf8") as fh:
            fh.write(svg_for(D[rid], stroke))
        refs.append({"id": rid, "title": title, "category": cat, "difficulty": diff, "style": style,
                     "asset": f"assets/library/{cat}/{rid}.svg", "featured": featured, "tags": tags})
    with open(os.path.join(ROOT, "library", "references.json"), "w", encoding="utf8") as fh:
        json.dump({"version": 1, "references": refs}, fh, ensure_ascii=False, indent=1)
    lessons = [lesson_json(*l) for l in LESSONS]
    os.makedirs(os.path.join(ROOT, "lessons"), exist_ok=True)
    with open(os.path.join(ROOT, "lessons", "lessons.json"), "w", encoding="utf8") as fh:
        json.dump({"version": 1, "lessons": lessons}, fh, ensure_ascii=False, indent=1)
    print(f"{len(refs)} references, {len(lessons)} lessons, {sum(len(l['steps']) for l in lessons)} lesson steps")


if __name__ == "__main__":
    main()
