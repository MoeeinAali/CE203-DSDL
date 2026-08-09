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
    id_to_name: dict[str, str] = {}
    for m in re.finditer(
        r"\$var\s+\w+\s+\d+\s+(\S+)\s+(\S+)(?:\s+\S+)?\s+\$end", text
    ):
        sid, name = m.group(1), m.group(2)
        id_to_name[sid] = name

    # timescale
    ts_m = re.search(r"\$timescale\s+(\d+)\s*([munpf]?s)\s*\$end", text)
    timescale_ps = 1000  # default 1ns
    if ts_m:
        n, unit = int(ts_m.group(1)), ts_m.group(2)
        mul = {"s": 1e12, "ms": 1e9, "us": 1e6, "ns": 1e3, "ps": 1, "fs": 1e-3}
        timescale_ps = n * mul.get(unit, 1e3)

    dump = text.split("$enddefinitions", 1)[-1]
    # strip $dumpvars ... $end then timestamps
    signals: dict[str, list[tuple[float, str]]] = {n: [] for n in id_to_name.values()}
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
            if sid in id_to_name:
                signals[id_to_name[sid]].append((time, val))
        elif line.startswith("b") or line.startswith("B"):
            parts = line.split()
            if len(parts) == 2 and parts[1] in id_to_name:
                signals[id_to_name[parts[1]]].append((time, parts[0][1:]))
    return signals, timescale_ps


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


def plot_wave(vcd: Path, out: Path, title: str, names: list[str]):
    signals, _ = parse_vcd(vcd)
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
    fig, axes = plt.subplots(n, 1, figsize=(10.5, fig_h), sharex=True)
    if n == 1:
        axes = [axes]

    colors = {
        "clk": "#1f4e79",
        "reset": "#c0392b",
        "A": "#27ae60",
        "B": "#16a085",
        "GT": "#8e44ad",
        "EQ": "#2980b9",
        "LT": "#d35400",
    }

    for ax, name in zip(axes, names):
        xs, ys = expand_steps(resolved[name], t_end)
        c = colors.get(name, "#333333")
        ax.plot(xs, ys, color=c, lw=1.6, solid_capstyle="butt", drawstyle="default")
        ax.fill_between(xs, ys, step=None, alpha=0.08, color=c)
        ax.set_ylim(-0.15, 1.35)
        ax.set_yticks([0, 1])
        ax.set_yticklabels(["0", "1"], fontsize=8)
        ax.set_ylabel(name, rotation=0, labelpad=28, va="center", fontsize=10, fontweight="bold")
        ax.grid(True, axis="x", ls=":", alpha=0.4)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    axes[-1].set_xlabel("time (ns)", fontsize=9)
    fig.suptitle(title, fontsize=12, fontweight="bold", y=0.98)
    fig.tight_layout(rect=[0.02, 0.02, 0.98, 0.94])
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
    args = ap.parse_args()
    plot_wave(args.vcd, args.output, args.title, [s.strip() for s in args.signals.split(",")])


if __name__ == "__main__":
    main()
