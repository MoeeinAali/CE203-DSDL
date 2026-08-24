#!/usr/bin/env bash
# Generate the VCD + PNG waveform for the incubator controller.
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

VCD="waves/incubator.vcd"
PNG="LaTeX-Template/figs/wave_incubator.png"

echo "=== waveform: incubator controller ==="
"$IVERILOG" -g2012 -I rtl \
  -DVCD_FILE="\"$VCD\"" \
  -o /tmp/tb_incubator_wave.vvp \
  rtl/seven_seg_decoder.v rtl/tick_gen.v rtl/main_fsm.v rtl/fan_fsm.v \
  rtl/incubator_controller.v tb/tb_incubator_wave.v
"$VVP" /tmp/tb_incubator_wave.vvp

"$PY" scripts/plot_vcd.py "$VCD" -o "$PNG" \
  -s "Clk,RstN,tick,temp,main_state,heater,cooler,fan_state,crs" \
  -f "temp=sdec,crs=dec,main_state=dec,fan_state=dec" \
  -t "Incubator control unit - full thermal cycle: heating, dead band, cooling with fan 4/6/8 RPS"

echo
echo "PNG file:"
ls -la "$PNG"
