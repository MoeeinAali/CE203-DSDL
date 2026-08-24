#!/usr/bin/env bash
# Compile & run all Lab06 testbenches with Icarus Verilog (iverilog + vvp).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"

RTL="rtl/seven_seg_decoder.v rtl/tick_gen.v rtl/main_fsm.v rtl/fan_fsm.v rtl/incubator_controller.v"

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
run_tb tb_incubator      $RTL tb/tb_incubator.v
# shellcheck disable=SC2086
run_tb tb_incubator_spec $RTL tb/tb_incubator_spec.v

total=$((pass + fail))
echo "summary: $pass/$total passed, $fail failed"
[[ "$fail" -eq 0 ]]
