#!/usr/bin/env python3
"""Generate bcd_divisibility.circ next to this script.

Two purely combinational, gates-only circuits for CE203-DSDL Lab 1:
  mod3_checker  -> 1 iff the 4-digit BCD input is a multiple of 3
  mod11_checker -> 1 iff the 4-digit BCD input is a multiple of 11
plus a `main` circuit that runs both side by side on shared inputs.

Math (both are purely combinational -- no state, no serial bit shifting):
  10 == 1 (mod 3)  => N mod 3 == (D0+D1+D2+D3) mod 3           (digit sum)
  10 == -1 (mod 11)=> N mod 11 == ((D0+D2)-(D1+D3)) mod 11      (alternating digit sum)
Both identities were brute-force verified against all 10000 BCD values
before any gate was placed (see README.md).

Only AND/OR/XOR/NOT gates are used anywhere (assignment: "basic gates only").
Everything is built hierarchically from two primitives:
  full_adder : 1-bit full adder, 5 gates (2 XOR + 2 AND + 1 OR)
  adderN     : N-bit ripple adder from N full_adder blocks (LSB Cin tied to GND)
mod3 reduces the 36-max digit sum with the classic binary bit-weight trick
(2^k mod 3 cycles +1,-1,...) down to a tiny 4-input gate network (cmp3).
mod11 compares the two alternating-sum halves directly against each other
and against each other +11, with a 10-input equality network (eq5) used 3x.

Geometry for 2-input AND/OR/XOR and 1-input NOT gates was taken from a
proven, working circuit (CE103-CAL Lab02's full_adder/adder2) and
independently re-verified by round-tripping tiny probe circuits through
logisim-evolution's `--test-vector` CLI:
  AND/OR : in1 = (x-50, y-20), in2 = (x-50, y+20), out = (x, y)
  XOR    : in1 = (x-60, y-20), in2 = (x-60, y+20), out = (x, y)
  NOT    : in  = (x-30, y),                        out = (x, y)
Subcircuit-instance ports follow the same convention used by the reference
project: a custom <appear> block maps each named local Pin to an (x,y)
offset from the instance's anchor; placing the instance at `loc` puts that
port at `loc + offset` in the parent circuit.
"""
from __future__ import annotations

import html
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bcd_divisibility.circ")

LIB = {"wiring": "0", "gates": "1", "base": "6"}

GATE_IN_OFFSET = {"AND Gate": 50, "OR Gate": 50, "XOR Gate": 60}
STUB = 30  # tunnel <-> component stub length


# --------------------------------------------------------------------------
# geometry helpers (splitter math ported from CE103-CAL Lab03's build_circ.py)
# --------------------------------------------------------------------------


def splitter_end(x: int, y: int, i: int, fanout: int, facing: str, appear: str, spacing: int):
    gap = spacing * 10
    width = 20
    justify = {"center": 0, "legacy": 0, "right": 1, "left": -1}[appear]
    if facing in ("north", "south"):
        raise NotImplementedError
    m = -1 if facing == "west" else 1
    dx_end0 = m * width
    if justify == 0:
        dy_end0 = -gap * (fanout // 2)
    elif m * justify > 0:
        dy_end0 = 10
    else:
        dy_end0 = -(10 + gap * (fanout - 1))
    return (x + dx_end0, y + dy_end0 + gap * i)


def spread(names: list[str], x: int, spacing: int = 20) -> dict[str, tuple[int, int]]:
    """Evenly space `names` vertically around y=0 at offset x, 20 units apart."""
    n = len(names)
    start = -(n - 1) * spacing // 2
    return {name: (x, start + i * spacing) for i, name in enumerate(names)}


# --------------------------------------------------------------------------
# circuit builder
# --------------------------------------------------------------------------


class Circuit:
    def __init__(self, name: str):
        self.name = name
        self.comps: list[str] = []
        self.wires: list[tuple[tuple[int, int], tuple[int, int]]] = []
        self.wire_net: list[str] = []
        self.appear: list[str] = []
        self.boxes: list[tuple[str, tuple[int, int, int, int]]] = []

    # -- raw ---------------------------------------------------------------
    def comp(self, lib: str | None, loc: tuple[int, int], name: str, attrs: dict | None = None):
        libattr = "" if lib is None else f'lib="{LIB[lib]}" '
        attrs = attrs or {}
        if not attrs:
            self.comps.append(f'    <comp {libattr}loc="({loc[0]},{loc[1]})" name="{name}"/>')
        else:
            body = "".join(
                f'\n      <a name="{k}" val="{html.escape(str(v), quote=True)}"/>'
                for k, v in attrs.items()
            )
            self.comps.append(
                f'    <comp {libattr}loc="({loc[0]},{loc[1]})" name="{name}">{body}\n    </comp>'
            )
        return loc

    def box(self, name: str, bb: tuple[int, int, int, int]):
        self.boxes.append((name, bb))

    def wire(self, a: tuple[int, int], b: tuple[int, int], net: str = "?"):
        if a == b:
            return
        assert a[0] == b[0] or a[1] == b[1], f"diagonal wire {a}->{b} in {self.name}"
        self.wires.append((a, b))
        self.wire_net.append(net)

    # -- library shorthands --------------------------------------------------
    def pin(self, loc, label, width=1, output=False):
        attrs = {"appearance": "classic", "label": label}
        if output:
            attrs["facing"] = "west"
            attrs["type"] = "output"
        if width != 1:
            attrs["width"] = str(width)
        w = 20 if width == 1 else 30
        x, y = loc
        if output:
            self.box(f"pin {label}", (x, y - 10, x + w, y + 10))
        else:
            self.box(f"pin {label}", (x - w, y - 10, x, y + 10))
        return self.comp("wiring", loc, "Pin", attrs)

    def tunnel(self, loc, label, facing="west", width=1):
        attrs = {}
        if facing != "west":
            attrs["facing"] = facing
        attrs["label"] = label
        if width != 1:
            attrs["width"] = str(width)
        bw, bh = max(10, 6 * len(label)), 12
        x, y = loc
        if facing == "east":
            self.box(f"tun {label}@{loc}", (x - bw - 8, y - bh // 2 - 3, x, y + bh // 2 + 3))
        else:
            self.box(f"tun {label}@{loc}", (x, y - bh // 2 - 3, x + bw + 8, y + bh // 2 + 3))
        return self.comp("wiring", loc, "Tunnel", attrs)

    def const(self, loc, value, facing="east", width=1):
        x, y = loc
        self.box(f"const {value}@{loc}", (x - 20, y - 10, x, y + 10))
        return self.comp("wiring", loc, "Constant",
                          {"facing": facing, "value": value, "width": str(width)})

    def splitter(self, loc, fanout, incoming, facing="east", appear="right", spacing=3):
        self.comp("wiring", loc, "Splitter", {
            "appear": appear, "facing": facing, "fanout": str(fanout),
            "incoming": str(incoming), "spacing": str(spacing)})
        ends = [splitter_end(loc[0], loc[1], i, fanout, facing, appear, spacing)
                for i in range(fanout)]
        xs = [loc[0]] + [e[0] for e in ends]
        ys = [loc[1]] + [e[1] for e in ends]
        self.box("splitter", (min(xs), min(ys) - 5, max(xs), max(ys) + 5))
        return lambda i: splitter_end(loc[0], loc[1], i, fanout, facing, appear, spacing)

    def gate(self, loc, kind, label=None):
        """2-input AND/OR/XOR or 1-input NOT Gate. Returns dict of absolute pin coords."""
        x, y = loc
        attrs = {"label": label} if label else {}
        self.comp("gates", loc, kind, attrs)
        if kind == "NOT Gate":
            self.box(f"{kind}@{loc}", (x - 30, y - 10, x, y + 10))
            return {"in": (x - 30, y), "out": (x, y)}
        off = GATE_IN_OFFSET[kind]
        self.box(f"{kind}@{loc}", (x - off, y - 25, x, y + 25))
        return {"in1": (x - off, y - 20), "in2": (x - off, y + 20), "out": (x, y)}

    def text(self, loc, s, size=14):
        self.comp("base", loc, "Text", {"font": f"SansSerif plain {size}", "text": s})

    def source(self, pt, label):
        """Drive tunnel `label` from a signal already present at pt (feeds rightward)."""
        x, y = pt
        tp = (x + STUB, y)
        self.wire(pt, tp, label)
        self.tunnel(tp, label)

    def sink(self, pt, label):
        """Feed tunnel `label` into the component input located at pt."""
        x, y = pt
        tp = (x - STUB, y)
        self.tunnel(tp, label, facing="east")
        self.wire(tp, pt, label)

    # -- emit ----------------------------------------------------------------
    def xml(self) -> str:
        out = [f'  <circuit name="{self.name}">']
        if self.appear:
            out.append('    <a name="appearance" val="custom"/>')
        out.append(f'    <a name="circuit" val="{self.name}"/>')
        out.append('    <a name="simulationFrequency" val="1.0"/>')
        if self.appear:
            out.append("    <appear>")
            out.extend("      " + a for a in self.appear)
            out.append("    </appear>")
        out.extend(sorted(self.comps))
        for (a, b) in sorted(self.wires):
            out.append(f'    <wire from="({a[0]},{a[1]})" to="({b[0]},{b[1]})"/>')
        out.append("  </circuit>")
        return "\n".join(out)


def instance(c: Circuit, loc, kind, spec, label):
    """Place a subcircuit instance; return dict of absolute port coordinates."""
    c.comp(None, loc, kind, {"label": label})
    x, y = loc
    w, h = spec["box"]
    both = {**spec["in"], **spec["out"]}
    ports = {name: (x + dx, y + dy) for name, (dx, dy) in both.items()}
    c.box(f"{label}:{kind}", (x - w // 2, y - h // 2, x + w // 2, y + h // 2))
    return ports


def make_appear(spec, local, label, font_size=9):
    w, h = spec["box"]
    lines = [
        f'<rect fill="#ffffff" height="{h}" stroke="#000000" stroke-width="2" '
        f'width="{w}" x="{-w // 2}" y="{-h // 2}"/>',
        f'<text dominant-baseline="central" font-family="SansSerif" font-size="{font_size}" '
        f'text-anchor="middle" x="0" y="{-h // 2 + font_size + 1}">{label}</text>',
        '<circ-anchor facing="east" x="0" y="0"/>',
    ]
    for name, (dx, dy) in spec["in"].items():
        lx, ly = local[name]
        lines.append(f'<circ-port dir="in" pin="{lx},{ly}" x="{dx}" y="{dy}"/>')
    for name, (dx, dy) in spec["out"].items():
        lx, ly = local[name]
        lines.append(f'<circ-port dir="out" pin="{lx},{ly}" x="{dx}" y="{dy}"/>')
    return lines


# ==========================================================================
# building block: full_adder (1 bit, 5 gates)
# ==========================================================================

FULL_ADDER_SPEC = {
    "box": (80, 80),
    "in": {"A": (-40, -30), "B": (-40, 0), "Cin": (-40, 30)},
    "out": {"S": (40, -20), "Cout": (40, 20)},
}


def build_full_adder():
    c = Circuit("full_adder")
    local = {}
    local["A"] = c.pin((100, 100), "A")
    local["B"] = c.pin((100, 200), "B")
    local["Cin"] = c.pin((100, 300), "Cin")
    c.source((100, 100), "A")
    c.source((100, 200), "B")
    c.source((100, 300), "Cin")

    x1 = c.gate((320, 110), "XOR Gate")   # X1 = A xor B
    c.sink(x1["in1"], "A")
    c.sink(x1["in2"], "B")
    p1 = c.gate((320, 220), "AND Gate")   # P1 = A and B
    c.sink(p1["in1"], "A")
    c.sink(p1["in2"], "B")
    c.source(x1["out"], "X1")
    c.source(p1["out"], "P1")

    x2 = c.gate((520, 110), "XOR Gate")   # S = X1 xor Cin
    c.sink(x2["in1"], "X1")
    c.sink(x2["in2"], "Cin")
    p2 = c.gate((520, 220), "AND Gate")   # P2 = X1 and Cin
    c.sink(p2["in1"], "X1")
    c.sink(p2["in2"], "Cin")
    c.source(p2["out"], "P2")

    local["S"] = (640, 110)
    c.pin(local["S"], "S", output=True)
    c.wire(x2["out"], local["S"], "S")

    or1 = c.gate((720, 220), "OR Gate")   # Cout = P1 or P2
    c.sink(or1["in1"], "P1")
    c.sink(or1["in2"], "P2")
    local["Cout"] = (840, 220)
    c.pin(local["Cout"], "Cout", output=True)
    c.wire(or1["out"], local["Cout"], "Cout")

    c.appear = make_appear(FULL_ADDER_SPEC, local, "FA")
    return c


# ==========================================================================
# building block: N-bit ripple adder from N full_adder instances
# ==========================================================================

def adder_spec(n):
    ins = spread([f"A{i}" for i in range(n)] + [f"B{i}" for i in range(n)], -50)
    outs = spread([f"S{i}" for i in range(n + 1)], 50)
    half = max([abs(v[1]) for v in ins.values()] + [abs(v[1]) for v in outs.values()])
    return {"box": (100, half * 2 + 40), "in": ins, "out": outs}


ADDER4_SPEC = adder_spec(4)
ADDER5_SPEC = adder_spec(5)


def build_adderN(n, name):
    c = Circuit(name)
    local = {}
    row = 300
    for i in range(n):
        fy = 250 + i * row
        p = instance(c, (700, fy), "full_adder", FULL_ADDER_SPEC, f"FA{i}")

        local[f"A{i}"] = (100, p["A"][1])
        c.pin(local[f"A{i}"], f"A{i}")
        c.wire(local[f"A{i}"], p["A"], f"A{i}")

        local[f"B{i}"] = (100, p["B"][1])
        c.pin(local[f"B{i}"], f"B{i}")
        c.wire(local[f"B{i}"], p["B"], f"B{i}")

        if i == 0:
            gloc = (p["Cin"][0] - 60, p["Cin"][1])
            c.const(gloc, "0x0")
            c.wire(gloc, p["Cin"], "GND0")
        else:
            c.sink(p["Cin"], f"CARRY{i}")

        local[f"S{i}"] = (1100, p["S"][1])
        c.pin(local[f"S{i}"], f"S{i}", output=True)
        c.wire(p["S"], local[f"S{i}"], f"S{i}")

        if i < n - 1:
            c.source(p["Cout"], f"CARRY{i + 1}")
        else:
            local[f"S{n}"] = (1100, p["Cout"][1])
            c.pin(local[f"S{n}"], f"S{n}", output=True)
            c.wire(p["Cout"], local[f"S{n}"], f"S{n}")

    c.appear = make_appear(adder_spec(n), local, f"+{n}b")
    return c


# ==========================================================================
# building block: cmp3 -- "P mod 3 == Q mod 3" for two 2-bit values P,Q in 0..3
# used to finish reducing the (<=36) BCD digit sum mod 3
# ==========================================================================

CMP3_SPEC = {
    "box": (100, 100),
    "in": spread(["p1", "p0", "q1", "q0"], -50),
    "out": spread(["Eq"], 50),
}


def build_cmp3():
    c = Circuit("cmp3")
    local = {}
    for name, y in (("p1", 100), ("p0", 200), ("q1", 300), ("q0", 400)):
        local[name] = (100, y)
        c.pin(local[name], name)
        c.source(local[name], name.upper())

    xh = c.gate((400, 150), "XOR Gate")
    c.sink(xh["in1"], "P1")
    c.sink(xh["in2"], "Q1")
    xl = c.gate((400, 350), "XOR Gate")
    c.sink(xl["in1"], "P0")
    c.sink(xl["in2"], "Q0")
    np1 = c.gate((400, 550), "NOT Gate")
    c.sink(np1["in"], "P1")
    np0 = c.gate((400, 700), "NOT Gate")
    c.sink(np0["in"], "P0")
    nq1 = c.gate((400, 850), "NOT Gate")
    c.sink(nq1["in"], "Q1")
    nq0 = c.gate((400, 1000), "NOT Gate")
    c.sink(nq0["in"], "Q0")
    c.source(xh["out"], "XORHI")
    c.source(xl["out"], "XORLO")
    c.source(np1["out"], "NP1")
    c.source(np0["out"], "NP0")
    c.source(nq1["out"], "NQ1")
    c.source(nq0["out"], "NQ0")

    eqh = c.gate((700, 150), "NOT Gate")   # p1 == q1
    c.sink(eqh["in"], "XORHI")
    eql = c.gate((700, 350), "NOT Gate")   # p0 == q0
    c.sink(eql["in"], "XORLO")
    a_g = c.gate((700, 550), "AND Gate")   # P == 0
    c.sink(a_g["in1"], "NP1")
    c.sink(a_g["in2"], "NP0")
    b_g = c.gate((700, 700), "AND Gate")   # Q == 3
    c.sink(b_g["in1"], "Q1")
    c.sink(b_g["in2"], "Q0")
    c_g = c.gate((700, 850), "AND Gate")   # P == 3
    c.sink(c_g["in1"], "P1")
    c.sink(c_g["in2"], "P0")
    d_g = c.gate((700, 1000), "AND Gate")  # Q == 0
    c.sink(d_g["in1"], "NQ1")
    c.sink(d_g["in2"], "NQ0")
    c.source(eqh["out"], "EQHI")
    c.source(eql["out"], "EQLO")
    c.source(a_g["out"], "A0T")
    c.source(b_g["out"], "B0T")
    c.source(c_g["out"], "C0T")
    c.source(d_g["out"], "D0T")

    t1 = c.gate((1000, 250), "AND Gate")   # P == Q
    c.sink(t1["in1"], "EQHI")
    c.sink(t1["in2"], "EQLO")
    t2 = c.gate((1000, 600), "AND Gate")   # P==0 & Q==3
    c.sink(t2["in1"], "A0T")
    c.sink(t2["in2"], "B0T")
    t3 = c.gate((1000, 950), "AND Gate")   # P==3 & Q==0
    c.sink(t3["in1"], "C0T")
    c.sink(t3["in2"], "D0T")
    c.source(t1["out"], "T1")
    c.source(t2["out"], "T2")
    c.source(t3["out"], "T3")

    or1 = c.gate((1300, 400), "OR Gate")
    c.sink(or1["in1"], "T1")
    c.sink(or1["in2"], "T2")
    c.source(or1["out"], "OR1")

    orf = c.gate((1600, 650), "OR Gate")
    c.sink(orf["in1"], "OR1")
    c.sink(orf["in2"], "T3")

    local["Eq"] = (1700, 650)
    c.pin(local["Eq"], "Eq", output=True)
    c.wire(orf["out"], local["Eq"], "EQ")

    c.appear = make_appear(CMP3_SPEC, local, "P%3=Q%3")
    return c


# ==========================================================================
# building block: eq5 -- 5-bit equality comparator (A[5] == B[5])
# used 3x by mod11_checker
# ==========================================================================

EQ5_SPEC = {
    "box": (100, 220),
    "in": spread([f"A{i}" for i in range(5)] + [f"B{i}" for i in range(5)], -50),
    "out": spread(["Eq"], 50),
}


def build_eq5():
    c = Circuit("eq5")
    local = {}
    rows = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
    names = [f"A{i}" for i in range(5)] + [f"B{i}" for i in range(5)]
    for name, y in zip(names, rows):
        local[name] = (100, y)
        c.pin(local[name], name)
        c.source(local[name], name.upper())

    xs = []
    for i in range(5):
        gy = 150 + i * 200
        g = c.gate((400, gy), "XOR Gate")
        c.sink(g["in1"], f"A{i}".upper())
        c.sink(g["in2"], f"B{i}".upper())
        c.source(g["out"], f"X{i}")
        xs.append(g)

    ns = []
    for i in range(5):
        gy = 150 + i * 200
        g = c.gate((700, gy), "NOT Gate")
        c.sink(g["in"], f"X{i}")
        c.source(g["out"], f"N{i}")
        ns.append(g)

    t1 = c.gate((1000, 250), "AND Gate")
    c.sink(t1["in1"], "N0")
    c.sink(t1["in2"], "N1")
    t2 = c.gate((1000, 650), "AND Gate")
    c.sink(t2["in1"], "N2")
    c.sink(t2["in2"], "N3")
    c.source(t1["out"], "T1")
    c.source(t2["out"], "T2")

    t3 = c.gate((1300, 450), "AND Gate")
    c.sink(t3["in1"], "T1")
    c.sink(t3["in2"], "T2")
    c.source(t3["out"], "T3")

    out = c.gate((1600, 700), "AND Gate")
    c.sink(out["in1"], "T3")
    c.sink(out["in2"], "N4")

    local["Eq"] = (1700, 700)
    c.pin(local["Eq"], "Eq", output=True)
    c.wire(out["out"], local["Eq"], "EQ")

    c.appear = make_appear(EQ5_SPEC, local, "A5=B5")
    return c


# ==========================================================================
# shared helper: split a 4-bit BCD digit pin into 4 named bit tunnels
# ==========================================================================

def split_digit(c: Circuit, loc, label):
    x, y = loc
    c.pin(loc, label, width=4)
    c.wire(loc, (x + 80, y), label)
    ends = c.splitter((x + 80, y), 4, 4)
    for k in range(4):
        p = ends(k)
        c.wire(p, (x + 200, p[1]), f"{label}B{k}")
        c.tunnel((x + 200, p[1]), f"{label}B{k}")
    return loc


# ==========================================================================
# top circuit: mod3_checker
# ==========================================================================

MOD_CHECKER_SPEC = {
    "box": (140, 140),
    "in": spread(["D0", "D1", "D2", "D3"], -70, spacing=40),
    "out": spread(["out"], 70),
}


def build_mod3_checker():
    c = Circuit("mod3_checker")
    local = {}

    for i, y in enumerate((200, 500, 800, 1100)):
        local[f"D{i}"] = split_digit(c, (100, y), f"D{i}")

    p_ab = instance(c, (700, 350), "adder4", ADDER4_SPEC, "AB")
    for k in range(4):
        c.sink(p_ab[f"A{k}"], f"D0B{k}")
        c.sink(p_ab[f"B{k}"], f"D1B{k}")
    for k in range(5):
        c.source(p_ab[f"S{k}"], f"SAB{k}")

    p_cd = instance(c, (700, 950), "adder4", ADDER4_SPEC, "CD")
    for k in range(4):
        c.sink(p_cd[f"A{k}"], f"D2B{k}")
        c.sink(p_cd[f"B{k}"], f"D3B{k}")
    for k in range(5):
        c.source(p_cd[f"S{k}"], f"SCD{k}")

    p_sum = instance(c, (1400, 650), "adder5", ADDER5_SPEC, "SUM")
    for k in range(5):
        c.sink(p_sum[f"A{k}"], f"SAB{k}")
        c.sink(p_sum[f"B{k}"], f"SCD{k}")
    for k in range(6):
        c.source(p_sum[f"S{k}"], f"SUM{k}")

    p_p = instance(c, (1900, 400), "full_adder", FULL_ADDER_SPEC, "P")
    c.sink(p_p["A"], "SUM0")
    c.sink(p_p["B"], "SUM2")
    c.sink(p_p["Cin"], "SUM4")
    c.source(p_p["S"], "P0")
    c.source(p_p["Cout"], "P1")

    p_q = instance(c, (1900, 700), "full_adder", FULL_ADDER_SPEC, "Q")
    c.sink(p_q["A"], "SUM1")
    c.sink(p_q["B"], "SUM3")
    c.sink(p_q["Cin"], "SUM5")
    c.source(p_q["S"], "Q0")
    c.source(p_q["Cout"], "Q1")

    p_cmp = instance(c, (2300, 550), "cmp3", CMP3_SPEC, "CMP")
    c.sink(p_cmp["p1"], "P1")
    c.sink(p_cmp["p0"], "P0")
    c.sink(p_cmp["q1"], "Q1")
    c.sink(p_cmp["q0"], "Q0")

    local["out"] = (2600, 550)
    c.pin(local["out"], "out", output=True)
    c.wire(p_cmp["Eq"], local["out"], "OUT")

    c.text((100, 100), "mod3_checker: out=1 iff D3D2D1D0 (BCD) is a multiple of 3", 16)
    c.appear = make_appear(MOD_CHECKER_SPEC, local, "%3=0", font_size=11)
    return c


# ==========================================================================
# top circuit: mod11_checker
# ==========================================================================

def const_bits(c: Circuit, ports, value_bits, tag):
    """Wire 5 individual bit-Constants (LSB first) directly into ports B0..B4."""
    for k, bit in enumerate(value_bits):
        pt = ports[f"B{k}"]
        cloc = (pt[0] - 60, pt[1])
        c.const(cloc, f"0x{bit}")
        c.wire(cloc, pt, f"{tag}{k}")


def build_mod11_checker():
    c = Circuit("mod11_checker")
    local = {}

    for i, y in enumerate((200, 500, 800, 1100)):
        local[f"D{i}"] = split_digit(c, (100, y), f"D{i}")

    p_a = instance(c, (700, 350), "adder4", ADDER4_SPEC, "A")   # A = D0+D2
    for k in range(4):
        c.sink(p_a[f"A{k}"], f"D0B{k}")
        c.sink(p_a[f"B{k}"], f"D2B{k}")
    for k in range(5):
        c.source(p_a[f"S{k}"], f"AA{k}")

    p_b = instance(c, (700, 950), "adder4", ADDER4_SPEC, "B")   # B = D1+D3
    for k in range(4):
        c.sink(p_b[f"A{k}"], f"D1B{k}")
        c.sink(p_b[f"B{k}"], f"D3B{k}")
    for k in range(5):
        c.source(p_b[f"S{k}"], f"BB{k}")

    p_ap = instance(c, (1400, 350), "adder5", ADDER5_SPEC, "AP11")  # A+11
    for k in range(5):
        c.sink(p_ap[f"A{k}"], f"AA{k}")
    const_bits(c, p_ap, "11010", "AC")  # 11 = 0b01011, LSB first: 1,1,0,1,0
    for k in range(5):
        c.source(p_ap[f"S{k}"], f"AP{k}")

    p_bp = instance(c, (1400, 950), "adder5", ADDER5_SPEC, "BP11")  # B+11
    for k in range(5):
        c.sink(p_bp[f"A{k}"], f"BB{k}")
    const_bits(c, p_bp, "11010", "BC")
    for k in range(5):
        c.source(p_bp[f"S{k}"], f"BP{k}")

    p_eq1 = instance(c, (2000, 250), "eq5", EQ5_SPEC, "EQ1")  # AP11 == B
    for k in range(5):
        c.sink(p_eq1[f"A{k}"], f"AP{k}")
        c.sink(p_eq1[f"B{k}"], f"BB{k}")
    c.source(p_eq1["Eq"], "EQ1")

    p_eq2 = instance(c, (2000, 650), "eq5", EQ5_SPEC, "EQ2")  # A == B
    for k in range(5):
        c.sink(p_eq2[f"A{k}"], f"AA{k}")
        c.sink(p_eq2[f"B{k}"], f"BB{k}")
    c.source(p_eq2["Eq"], "EQ2")

    p_eq3 = instance(c, (2000, 1050), "eq5", EQ5_SPEC, "EQ3")  # A == BP11
    for k in range(5):
        c.sink(p_eq3[f"A{k}"], f"AA{k}")
        c.sink(p_eq3[f"B{k}"], f"BP{k}")
    c.source(p_eq3["Eq"], "EQ3")

    or1 = c.gate((2400, 450), "OR Gate")
    c.sink(or1["in1"], "EQ1")
    c.sink(or1["in2"], "EQ2")
    c.source(or1["out"], "OR1")

    orf = c.gate((2700, 750), "OR Gate")
    c.sink(orf["in1"], "OR1")
    c.sink(orf["in2"], "EQ3")

    local["out"] = (2800, 750)
    c.pin(local["out"], "out", output=True)
    c.wire(orf["out"], local["out"], "OUT")

    c.text((100, 100), "mod11_checker: out=1 iff D3D2D1D0 (BCD) is a multiple of 11", 16)
    c.appear = make_appear(MOD_CHECKER_SPEC, local, "%11=0", font_size=11)
    return c


# ==========================================================================
# top circuit: main -- both checkers on shared inputs
# ==========================================================================

def build_main():
    c = Circuit("main")
    c.text((100, 100), "BCD divisibility checkers (basic gates only) -- Lab 1", 20)
    c.text((100, 140), "D3 D2 D1 D0 = decimal digits (thousands..units), each 4-bit BCD", 12)

    pins = {}
    for i, y in enumerate((250, 350, 450, 550)):
        pins[f"D{i}"] = c.pin((100, y), f"D{i}", width=4)
        c.wire(pins[f"D{i}"], (200, y), f"D{i}")
        c.tunnel((200, y), f"D{i}", width=4)

    p3 = instance(c, (700, 350), "mod3_checker", MOD_CHECKER_SPEC, "MOD3")
    p11 = instance(c, (700, 750), "mod11_checker", MOD_CHECKER_SPEC, "MOD11")
    for i in range(4):
        c.tunnel((p3[f"D{i}"][0] - 60, p3[f"D{i}"][1]), f"D{i}", facing="east", width=4)
        c.wire((p3[f"D{i}"][0] - 60, p3[f"D{i}"][1]), p3[f"D{i}"], f"D{i}")
        c.tunnel((p11[f"D{i}"][0] - 60, p11[f"D{i}"][1]), f"D{i}", facing="east", width=4)
        c.wire((p11[f"D{i}"][0] - 60, p11[f"D{i}"][1]), p11[f"D{i}"], f"D{i}")

    o3 = c.pin((900, 350), "mult_of_3", output=True)
    c.wire(p3["out"], o3, "OUT3")
    o11 = c.pin((900, 750), "mult_of_11", output=True)
    c.wire(p11["out"], o11, "OUT11")
    return c


# ==========================================================================
# header / sanity checks / emit
# ==========================================================================

HEADER = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<project source="4.1.0" version="1.0">
  This file is intended to be loaded by Logisim-evolution v4.1.0(https://github.com/logisim-evolution/).

  <lib desc="#Wiring" name="0">
    <tool name="Pin">
      <a name="appearance" val="classic"/>
    </tool>
  </lib>
  <lib desc="#Gates" name="1"/>
  <lib desc="#Base" name="6"/>
  <main name="main"/>
  <options>
    <a name="gateUndefined" val="ignore"/>
    <a name="simlimit" val="1000"/>
    <a name="simrand" val="0"/>
  </options>
  <mappings>
    <tool lib="6" map="Button2" name="Poke Tool"/>
    <tool lib="6" map="Button3" name="Menu Tool"/>
    <tool lib="6" map="Ctrl Button1" name="Menu Tool"/>
  </mappings>
  <toolbar>
    <tool lib="6" name="Poke Tool"/>
    <tool lib="6" name="Edit Tool"/>
    <tool lib="6" name="Wiring Tool"/>
    <tool lib="6" name="Text Tool"/>
    <sep/>
    <tool lib="0" name="Pin"/>
    <tool lib="0" name="Pin">
      <a name="facing" val="west"/>
      <a name="type" val="output"/>
    </tool>
    <sep/>
    <tool lib="1" name="NOT Gate"/>
    <tool lib="1" name="AND Gate"/>
    <tool lib="1" name="OR Gate"/>
    <tool lib="1" name="XOR Gate"/>
  </toolbar>
'''


def check(c: Circuit) -> list[str]:
    """Collinear overlaps and endpoint-on-segment contacts between wires of
    different nets -- the same short-circuit bug class documented in the
    CE103-CAL Lab02/Lab03 READMEs."""
    problems = []
    segs = []
    for (a, b), net in zip(c.wires, c.wire_net):
        (x1, y1), (x2, y2) = sorted([a, b])
        segs.append((x1, y1, x2, y2, net))

    for i in range(len(segs)):
        x1, y1, x2, y2, n1 = segs[i]
        for j in range(i + 1, len(segs)):
            a1, b1, a2, b2, n2 = segs[j]
            if n1 == n2:
                continue
            if y1 == y2 == b1 == b2 and max(x1, a1) < min(x2, a2):
                problems.append(f"{c.name}: collinear H overlap {n1}/{n2} at y={y1}")
            if x1 == x2 == a1 == a2 and max(y1, b1) < min(y2, b2):
                problems.append(f"{c.name}: collinear V overlap {n1}/{n2} at x={x1}")
            for (px, py) in ((a1, b1), (a2, b2)):
                if y1 == y2 and py == y1 and x1 <= px <= x2:
                    problems.append(f"{c.name}: T-contact {n2} endpoint ({px},{py}) on {n1}")
                if x1 == x2 and px == x1 and y1 <= py <= y2:
                    problems.append(f"{c.name}: T-contact {n2} endpoint ({px},{py}) on {n1}")
            for (px, py) in ((x1, y1), (x2, y2)):
                if b1 == b2 and py == b1 and a1 <= px <= a2:
                    problems.append(f"{c.name}: T-contact {n1} endpoint ({px},{py}) on {n2}")
                if a1 == a2 and px == a1 and b1 <= py <= b2:
                    problems.append(f"{c.name}: T-contact {n1} endpoint ({px},{py}) on {n2}")
    return sorted(set(problems))


def check_boxes(c: Circuit) -> list[str]:
    problems = []
    bs = c.boxes
    for i in range(len(bs)):
        n1, (ax1, ay1, ax2, ay2) = bs[i]
        for j in range(i + 1, len(bs)):
            n2, (bx1, by1, bx2, by2) = bs[j]
            if ax1 < bx2 and bx1 < ax2 and ay1 < by2 and by1 < ay2:
                problems.append(f"{c.name}: component overlap: {n1} / {n2}")
    return sorted(set(problems))


def main():
    circuits = [
        build_full_adder(),
        build_adderN(4, "adder4"),
        build_adderN(5, "adder5"),
        build_cmp3(),
        build_eq5(),
        build_mod3_checker(),
        build_mod11_checker(),
        build_main(),
    ]

    total_problems = 0
    for c in circuits:
        probs = check(c) + check_boxes(c)
        if probs:
            total_problems += len(probs)
            print(f"!! {c.name}: {len(probs)} wiring/layout problems")
            for p in probs[:20]:
                print("   ", p)
        else:
            print(f"ok  {c.name}: {len(c.wires)} wires, {len(c.comps)} components, no conflicts")

    with open(OUT, "w") as f:
        f.write(HEADER)
        for c in circuits:
            f.write(c.xml() + "\n")
        f.write("</project>\n")
    print("wrote", OUT)
    if total_problems:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
