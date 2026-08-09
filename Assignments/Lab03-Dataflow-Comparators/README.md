# Lab 03 — توصیف جریان داده (مقایسه‌کننده‌ی آبشاری و سریال)

| | |
|---|---|
| RTL | [`rtl/`](rtl/) |
| Testbenches | [`tb/`](tb/) |
| Simulator | Icarus Verilog (`iverilog` / `vvp`) |
| Report | [`LaTeX-Template/HW.pdf`](LaTeX-Template/HW.pdf) |

## قسمت ۱ — مقایسه‌کننده ترکیبی سلسله‌مراتبی

- `cascadable_1bit_comparator.v` — فقط `assign`
- `comparator_4bit.v` — چهار نمونه‌ی آبشاری، MSB→LSB، دانه `(GT,EQ,LT)=(0,1,0)`

## قسمت ۲ — مقایسه‌کننده سریال

| نسخه | فایل | نگهداری حالت |
|------|------|----------------|
| A | `serial_comparator_ff.v` | next-state با `assign` + `always @(posedge clk or posedge reset)` |
| B | `serial_comparator_assign.v` | فقط `assign` (مسترـ‌اسلیو latch) |

ورودی‌ها: `clk`, `reset` (async active-high), `A`, `B` (MSB-first). خروجی: `GT`, `EQ`, `LT`.

## تست

```bash
./run_tests.sh
```

انتظار: `4/4 passed` (32 + 256 + 312 + 312 چک).

## شکل‌موج (A و B)

```bash
./scripts/gen_waves.sh
```

خروجی PNG:
- `LaTeX-Template/figs/wave_serial_ff.png` (نسخه A)
- `LaTeX-Template/figs/wave_serial_assign.png` (نسخه B)
