#!/usr/bin/env bash
# Compile & run all Lab04 testbenches with Icarus Verilog (iverilog + vvp).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"

pass=0
fail=0

run_tb() {
  local name="$1"
  shift
  local out
  echo "=== $name ==="
  if out="$("$IVERILOG" -g2012 -o "/tmp/${name}.vvp" "$@" 2>&1)"; then
    if runout="$("$VVP" "/tmp/${name}.vvp" 2>&1)"; then
      echo "$runout" | sed -n '/Passed:/p;/FAIL/p;/Passed:/!{/Failed:/p;}'
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

run_tb tb_stack        rtl/stack.v tb/tb_stack.v
run_tb tb_stack_param  rtl/stack.v tb/tb_stack_param.v

total=$((pass + fail))
echo "summary: $pass/$total passed, $fail failed"
[[ "$fail" -eq 0 ]]
