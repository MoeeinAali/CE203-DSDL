#!/usr/bin/env bash
# Generate the VCD + PNG waveform for the pipelined complex machine.
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

VCD="waves/complex_cpu.vcd"
PNG="LaTeX-Template/figs/wave_complex_cpu.png"

echo "=== waveform: pipelined complex machine ==="
"$IVERILOG" -g2012 -I rtl \
  -DVCD_FILE="\"$VCD\"" \
  -o /tmp/tb_complex_wave.vvp \
  rtl/mul_unit.v rtl/add_unit.v rtl/complex_alu.v \
  rtl/regfile.v rtl/imem.v rtl/complex_cpu.v \
  tb/tb_complex_wave.v
"$VVP" /tmp/tb_complex_wave.vvp

"$PY" scripts/plot_vcd.py "$VCD" -o "$PNG" \
  -s "RstN,pc,ex_busy,alu_busy,st,wb_we,wb_rd,wb_data,halted" \
  -f "pc=dec,st=dec,wb_rd=dec,wb_data=hex" \
  -t "Pipelined complex machine: r3 = r1*r2, r4 = r1+r2, r5 = r3-r4, r6 = r5*r1"

echo
echo "PNG file:"
ls -la "$PNG"
