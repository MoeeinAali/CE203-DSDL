#!/usr/bin/env bash
# Generate the VCD + PNG waveform for the behavioural stack.
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

VCD="waves/stack.vcd"
PNG="LaTeX-Template/figs/wave_stack.png"

echo "=== waveform: stack ==="
"$IVERILOG" -g2012 \
  -DVCD_FILE="\"$VCD\"" \
  -o /tmp/tb_stack_wave.vvp \
  rtl/stack.v tb/tb_stack_wave.v
"$VVP" /tmp/tb_stack_wave.vvp

"$PY" scripts/plot_vcd.py "$VCD" -o "$PNG" \
  -s "Clk,RstN,Push,Pop,Data_In,Data_Out,Full,Empty" \
  -t "Behavioural stack (DEPTH=8, WIDTH=4) - reset, pop-on-empty, fill to Full, push-on-full, drain to Empty"

echo
echo "PNG file:"
ls -la "$PNG"
