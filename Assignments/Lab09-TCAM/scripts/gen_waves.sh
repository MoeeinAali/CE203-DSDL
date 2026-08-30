#!/usr/bin/env bash
# Generate the VCD + PNG waveform for the TCAM.
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

VCD="waves/tcam.vcd"
PNG="LaTeX-Template/figs/wave_tcam.png"

echo "=== waveform: 16 x 16 TCAM ==="
"$IVERILOG" -g2012 -I rtl \
  -DVCD_FILE="\"$VCD\"" \
  -o /tmp/tb_tcam_wave.vvp \
  rtl/tcam_cell.v rtl/tcam_entry.v rtl/priority_encoder.v rtl/tcam.v \
  tb/tb_tcam_wave.v
"$VVP" /tmp/tb_tcam_wave.vvp

"$PY" scripts/plot_vcd.py "$VCD" -o "$PNG" \
  -s "RstN,we,waddr,search,match_lines,hit,match_addr,match_count" \
  -f "waddr=dec,search=hex,match_lines=hex,match_addr=dec,match_count=dec" \
  -t "16 x 16 TCAM: one search word lights several match lines, lowest index wins"

echo
echo "PNG file:"
ls -la "$PNG"
