#!/usr/bin/env bash
# Compile & run all Lab08 testbenches with Icarus Verilog (iverilog + vvp).
#
# Before the simulations there is a structural check: the lab sheet allows a
# single adder and a single multiplier in the whole machine, and that is a
# property of the source text, not of any waveform. Counting instantiations is
# the only way to actually verify it, so it runs as test number one.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"

RTL="rtl/mul_unit.v rtl/add_unit.v rtl/complex_alu.v rtl/regfile.v rtl/imem.v rtl/complex_cpu.v"

pass=0
fail=0

# Count instantiations of a module across the RTL (declarations excluded).
count_inst() {
  local mod="$1"
  grep -hE "^[[:space:]]*${mod}[[:space:]]+[A-Za-z_]" rtl/*.v | grep -vc "^[[:space:]]*module" || true
}

echo "=== resource check (one adder, one multiplier) ==="
rc_ok=1
for mod in mul_unit add_unit complex_alu; do
  n="$(count_inst "$mod")"
  if [[ "$n" -eq 1 ]]; then
    echo "  $mod instantiated $n time"
  else
    echo "  $mod instantiated $n times  <-- must be exactly 1"
    rc_ok=0
  fi
done
if [[ "$rc_ok" -eq 1 ]]; then
  echo "PASS: resource check"
  pass=$((pass + 1))
else
  echo "FAIL: resource check"
  fail=$((fail + 1))
fi
echo

run_tb() {
  local name="$1"
  shift
  local out
  echo "=== $name ==="
  if out="$("$IVERILOG" -g2012 -I rtl -o "/tmp/${name}.vvp" "$@" 2>&1)"; then
    if runout="$("$VVP" "/tmp/${name}.vvp" 2>&1)"; then
      echo "$runout" | sed -n '/cycles/p;/Passed:/p;/FAIL/p'
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
run_tb tb_complex_addsub  $RTL tb/tb_complex_addsub.v
# shellcheck disable=SC2086
run_tb tb_complex_mul     $RTL tb/tb_complex_mul.v
# shellcheck disable=SC2086
run_tb tb_complex_cpu     $RTL tb/tb_complex_cpu.v
# shellcheck disable=SC2086
run_tb tb_complex_cpu_spec $RTL tb/tb_complex_cpu_spec.v

total=$((pass + fail))
echo "summary: $pass/$total passed, $fail failed"
[[ "$fail" -eq 0 ]]
