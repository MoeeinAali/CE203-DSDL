#!/usr/bin/env bash
# Compile & run all Lab07 testbenches with Icarus Verilog (iverilog + vvp).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"

RTL="rtl/baud_gen.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart.v rtl/uart_link.v"

pass=0
fail=0

run_tb() {
  local name="$1"
  shift
  local out
  echo "=== $name ==="
  if out="$("$IVERILOG" -g2012 -I rtl -o "/tmp/${name}.vvp" "$@" 2>&1)"; then
    if runout="$("$VVP" "/tmp/${name}.vvp" 2>&1)"; then
      echo "$runout" | sed -n '/Passed:/p;/FAIL/p'
      if echo "$runout" | grep -q 'Failed: 0'; then
        echo "PASS: $name"
        pass=$((pass + 1))
      else
        echo "$runout"
        echo "FAIL: $name"
        fail=$((fail + 1))
      fi
    else
      echo "$runout"
      echo "FAIL: $name (vvp)"
      fail=$((fail + 1))
    fi
  else
    echo "$out"
    echo "FAIL: $name (compile)"
    fail=$((fail + 1))
  fi
  echo
}

echo "iverilog: $("$IVERILOG" -V 2>&1 | head -1)"
echo

# shellcheck disable=SC2086
run_tb tb_uart_tx   $RTL tb/tb_uart_tx.v
# shellcheck disable=SC2086
run_tb tb_uart_rx   $RTL tb/tb_uart_rx.v
# shellcheck disable=SC2086
run_tb tb_uart_link $RTL tb/tb_uart_link.v

total=$((pass + fail))
echo "summary: $pass/$total passed, $fail failed"
[[ "$fail" -eq 0 ]]
