#!/usr/bin/env bash
# Generate the VCD + PNG waveform for the Booth multiplier.
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

VCD="waves/booth.vcd"
PNG="LaTeX-Template/figs/wave_booth.png"

echo "=== waveform: booth multiplier ==="
"$IVERILOG" -g2012 \
  -DVCD_FILE="\"$VCD\"" \
  -o /tmp/tb_booth_wave.vvp \
  rtl/booth_datapath.v rtl/booth_control.v rtl/booth_multiplier.v \
  tb/tb_booth_wave.v
"$VVP" /tmp/tb_booth_wave.vvp

"$PY" scripts/plot_vcd.py "$VCD" -o "$PNG" \
  -s "Clk,RstN,start,busy,done,load,step,cnt,window,Multiplicand,Multiplier,Product" \
  -t "Radix-4 Booth multiplier (N=8) - 25 x (-7) = -175, then (-12) x (-11) = +132; 5 clocks each"

echo
echo "PNG file:"
ls -la "$PNG"
