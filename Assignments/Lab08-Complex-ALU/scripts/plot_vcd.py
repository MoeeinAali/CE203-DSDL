#!/usr/bin/env python3
"""Minimal VCD → digital waveform PNG (stdlib + matplotlib)."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle


def parse_vcd(path: Path):
    text = path.read_text()
    # One VCD identifier can carry several names: a net that is passed through
    # a port hierarchy is dumped once per scope under a different leaf name
    # (tb.a_to_b, link.a_to_b, u_a.txd, ...). Keeping only the last name would
    # silently drop every other alias, so every name is remembered.
    id_to_names: dict[str, list[str]] = {}
    id_to_width: dict[str, int] = {}
    for m in re.finditer(
        r"\$var\s+\w+\s+(\d+)\s+(\S+)\s+(\S+)(?:\s+\S+)?\s+\$end", text
    ):
        width, sid, name = int(m.group(1)), m.group(2), m.group(3)
        names = id_to_names.setdefault(sid, [])
        if name not in names:
            names.append(name)
        id_to_width[name] = width

    # timescale
    ts_m = re.search(r"\$timescale\s+(\d+)\s*([munpf]?s)\s*\$end", text)
    timescale_ps = 1000  # default 1ns
    if ts_m:
        n, unit = int(ts_m.group(1)), ts_m.group(2)
        mul = {"s": 1e12, "ms": 1e9, "us": 1e6, "ns": 1e3, "ps": 1, "fs": 1e-3}
        timescale_ps = n * mul.get(unit, 1e3)

    dump = text.split("$enddefinitions", 1)[-1]
    # strip $dumpvars ... $end then timestamps
    signals: dict[str, list[tuple[float, str]]] = {
        n: [] for names in id_to_names.values() for n in names
    }
    time = 0.0
    for line in dump.splitlines():
        line = line.strip()
        if not line or line.startswith("$"):
            continue
        if line.startswith("#"):
            time = int(line[1:]) * (timescale_ps / 1000.0)  # ns
            continue
        # scalar: 0!<id> or bxxxx <id>
        if line[0] in "01xzXZ" and len(line) >= 2:
            val, sid = line[0].lower(), line[1:]
            for nm in id_to_names.get(sid, ()):
                signals[nm].append((time, val))
        elif line.startswith("b") or line.startswith("B"):
            parts = line.split()
            if len(parts) == 2:
                for nm in id_to_names.get(parts[1], ()):
                    signals[nm].append((time, parts[0][1:]))
    return signals, timescale_ps, id_to_width


def expand_steps(samples: list[tuple[float, str]], t_end: float):
    if not samples:
        return [0.0, t_end], [0, 0]
    xs, ys = [], []
    for i, (t, v) in enumerate(samples):
        y = 1 if v in ("1",) else 0
        if not xs:
            xs.append(t)
            ys.append(y)
        else:
            xs.append(t)
            ys.append(ys[-1])
            xs.append(t)
            ys.append(y)
    xs.append(t_end)
    ys.append(ys[-1])
    return xs, ys


def bus_label(bits: str, width: int, fmt: str = "hex") -> str:
    """Render a VCD binary string per `fmt`: hex, dec, or signed decimal."""
    b = bits.lower()
    if any(c in "xz" for c in b):
        return b[0] * (1 if fmt != "hex" else max(1, (width + 3) // 4))
    val = int(b, 2)
    if fmt == "sdec":
        # VCD drops leading zeros, so re-extend to the declared width first.
        b = b.zfill(width)
        if b[0] == "1":
            val -= 1 << width
        return str(val)
    if fmt == "dec":
        return str(val)
    return f"{val:0{max(1, (width + 3) // 4)}X}"


def draw_bus(ax, samples, t_end, width, color, fmt="hex"):
    """Draw a bus lane: an elongated hexagon per value, labelled in hex."""
    if not samples:
        return
    for i, (t, v) in enumerate(samples):
        t_next = samples[i + 1][0] if i + 1 < len(samples) else t_end
        if t_next <= t:
            continue
        k = min(0.35, (t_next - t) * 0.18)  # bevel width
        xs = [t, t + k, t_next - k, t_next, t_next - k, t + k]
        ys = [0.5, 1.0, 1.0, 0.5, 0.0, 0.0]
        ax.fill(xs, ys, color=color, alpha=0.13, zorder=1)
        ax.plot(xs + [xs[0]], ys + [ys[0]], color=color, lw=1.4,
                solid_joinstyle="miter", zorder=2)
        if t_next - t > 0.9:
            ax.text((t + t_next) / 2.0, 0.5, bus_label(v, width, fmt),
                    ha="center", va="center", fontsize=7,
                    family="monospace", color="#222222", zorder=3)


def plot_wave(vcd: Path, out: Path, title: str, names: list[str],
               fmts: dict[str, str] | None = None):
    signals, _, widths = parse_vcd(vcd)
    # Resolve names: prefer exact, else suffix match (hier paths)
    resolved = {}
    for want in names:
        if want in signals:
            resolved[want] = signals[want]
            continue
        matches = [k for k in signals if k == want or k.endswith("." + want) or k.endswith(want)]
        if matches:
            # shortest path / leaf preferred
            matches.sort(key=len)
            resolved[want] = signals[matches[0]]
        else:
            resolved[want] = []

    t_end = 0.0
    for samples in resolved.values():
        if samples:
            t_end = max(t_end, samples[-1][0])
    t_end = max(t_end + 2.0, 1.0)

    n = len(names)
    fig_h = max(2.2, 0.55 * n + 0.8)
    fig, axes = plt.subplots(n, 1, figsize=(11.5, fig_h), sharex=True)
    if n == 1:
        axes = [axes]

    colors = {
        "clk": "#1f4e79",
        "Clk": "#1f4e79",
        "reset": "#c0392b",
        "RstN": "#c0392b",
        "Push": "#27ae60",
        "Pop": "#d35400",
        "Data_In": "#2c3e50",
        "Data_Out": "#6c3483",
        "Full": "#8e44ad",
        "Empty": "#2980b9",
        "A": "#27ae60",
        "B": "#16a085",
        "GT": "#8e44ad",
        "EQ": "#2980b9",
        "LT": "#d35400",
        # Lab05 (Booth multiplier)
        "start": "#27ae60",
        "busy": "#2980b9",
        "done": "#8e44ad",
        "load": "#16a085",
        "step": "#d35400",
        "cnt": "#7f8c8d",
        "window": "#b7950b",
        "Multiplicand": "#2c3e50",
        "Multiplier": "#34495e",
        "Product": "#6c3483",
        # Lab08 (complex ALU / pipelined machine)
        "pc": "#2c3e50",
        "ex_busy": "#2980b9",
        "alu_busy": "#8e44ad",
        "st": "#b7950b",
        "wb_we": "#27ae60",
        "wb_rd": "#16a085",
        "wb_data": "#6c3483",
        "halted": "#c0392b",
        # Lab06 (incubator controller)
        "tick": "#7f8c8d",
        "temp": "#2c3e50",
        "main_state": "#2980b9",
        "heater": "#c0392b",
        "cooler": "#2980b9",
        "fan_state": "#16a085",
        "crs": "#8e44ad",
    }

    for ax, name in zip(axes, names):
        c = colors.get(name, "#333333")
        w = widths.get(name, 1)
        if w > 1:
            draw_bus(ax, resolved[name], t_end, w, c,
                     (fmts or {}).get(name, "hex"))
            ax.set_yticks([])
        else:
            xs, ys = expand_steps(resolved[name], t_end)
            ax.plot(xs, ys, color=c, lw=1.6, solid_capstyle="butt", drawstyle="default")
            ax.fill_between(xs, ys, step=None, alpha=0.08, color=c)
            ax.set_yticks([0, 1])
            ax.set_yticklabels(["0", "1"], fontsize=8)
        ax.set_ylim(-0.15, 1.35)
        ax.set_xlim(0, t_end)
        ax.set_ylabel(name, rotation=0, labelpad=34, va="center", ha="right",
                      fontsize=9, fontweight="bold")
        ax.grid(True, axis="x", ls=":", alpha=0.4)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    axes[-1].set_xlabel("time (ns)", fontsize=9)
    fig.suptitle(title, fontsize=11, fontweight="bold", y=0.985)
    fig.tight_layout(rect=[0.02, 0.02, 0.99, 0.93])
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=160)
    plt.close(fig)
    print(f"Wrote {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd", type=Path)
    ap.add_argument("-o", "--output", type=Path, required=True)
    ap.add_argument("-t", "--title", default="Waveform")
    ap.add_argument(
        "-s",
        "--signals",
        default="clk,reset,A,B,GT,EQ,LT",
        help="Comma-separated signal leaf names",
    )
    ap.add_argument(
        "-f",
        "--format",
        default="",
        help="Per-signal display format, e.g. 'temp=sdec,crs=dec'",
    )
    args = ap.parse_args()
    fmts = {}
    for item in args.format.split(","):
        if "=" in item:
            k, v = item.split("=", 1)
            fmts[k.strip()] = v.strip()
    plot_wave(args.vcd, args.output, args.title,
              [s.strip() for s in args.signals.split(",")], fmts)


if __name__ == "__main__":
    main()
