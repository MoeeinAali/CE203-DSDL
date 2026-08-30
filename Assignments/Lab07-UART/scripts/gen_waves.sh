#!/usr/bin/env bash
# Generate the VCD + PNG waveform for the UART link.
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

VCD="waves/uart.vcd"
PNG="LaTeX-Template/figs/wave_uart.png"

echo "=== waveform: UART link ==="
"$IVERILOG" -g2012 -I rtl \
  -DVCD_FILE="\"$VCD\"" \
  -o /tmp/tb_uart_wave.vvp \
  rtl/baud_gen.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart.v rtl/uart_link.v \
  tb/tb_uart_wave.v
"$VVP" /tmp/tb_uart_wave.vvp

"$PY" scripts/plot_vcd.py "$VCD" -o "$PNG" \
  -s "RstN,a_tx_start,a_to_b,b_rx_valid,b_rx_reg,b_tx_start,b_to_a,a_rx_valid,a_rx_reg" \
  -f "a_rx_reg=hex,b_rx_reg=hex" \
  -t "Two UART units exchanging characters: A sends 'K' (0x4B) while B sends 'z' (0x7A)"

echo
echo "PNG file:"
ls -la "$PNG"
