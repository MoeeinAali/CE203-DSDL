#!/usr/bin/env bash
# Generate VCD + PNG waveforms for serial comparator A and B.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
PY="${PY:-$DIR/.venv/bin/python}"
if [[ ! -x "$PY" ]]; then
  PY="$(command -v python3)"
fi

mkdir -p waves LaTeX-Template/figs

gen_one() {
  local tag="$1"   # ff | assign
  local mod="$2"
  local title="$3"
  local vcd="waves/serial_${tag}.vcd"
  local png="LaTeX-Template/figs/wave_serial_${tag}.png"

  echo "=== waveform $tag ($mod) ==="
  "$IVERILOG" -g2012 \
    -DDUT_MODULE="$mod" \
    -DVCD_FILE="\"$vcd\"" \
    -o "/tmp/tb_serial_wave_${tag}.vvp" \
    "rtl/${mod}.v" tb/tb_serial_wave.v
  "$VVP" "/tmp/tb_serial_wave_${tag}.vvp"
  "$PY" scripts/plot_vcd.py "$vcd" -o "$png" -t "$title"
}

gen_one ff     serial_comparator_ff     "Serial comparator A (FF / always) — A=0100 vs B=0011, then reset + A=0001 vs B=0010"
gen_one assign serial_comparator_assign "Serial comparator B (assign-only) — same stimulus as A"

echo
echo "PNG files:"
ls -la LaTeX-Template/figs/wave_serial_*.png
