#!/usr/bin/env python3
"""Generate all .vec test-vector files for bcd_divisibility.circ."""
import os

DIR = os.path.dirname(os.path.abspath(__file__))


def write_vec(fname, header, rows):
    path = os.path.join(DIR, fname)
    with open(path, "w") as f:
        f.write(f"<Set> <Seq> {header}\n")
        for i, row in enumerate(rows, 1):
            f.write(f"{i} 1 {row}\n")
    print(f"wrote {fname}: {len(rows)} rows")


def bits(n, width):
    return [(n >> k) & 1 for k in range(width)]  # LSB first


# ---- full_adder: A,B,Cin -> S,Cout -----------------------------------
rows = []
for a in range(2):
    for b in range(2):
        for cin in range(2):
            s = a ^ b ^ cin
            cout = (a & b) | (cin & (a ^ b))
            rows.append(f"{a} {b} {cin} {s} {cout}")
write_vec("tests_full_adder.vec", "A B Cin S Cout", rows)

# ---- adder4: A0..A3,B0..B3 -> S0..S4 (exhaustive 256) -----------------
rows = []
for a in range(16):
    for b in range(16):
        total = a + b
        ab = " ".join(str(x) for x in bits(a, 4))
        bb = " ".join(str(x) for x in bits(b, 4))
        sb = " ".join(str(x) for x in bits(total, 5))
        rows.append(f"{ab} {bb} {sb}")
write_vec("tests_adder4.vec", "A0 A1 A2 A3 B0 B1 B2 B3 S0 S1 S2 S3 S4", rows)

# ---- adder5: A0..A4,B0..B4 -> S0..S5 (exhaustive 1024) -----------------
rows = []
for a in range(32):
    for b in range(32):
        total = a + b
        ab = " ".join(str(x) for x in bits(a, 5))
        bb = " ".join(str(x) for x in bits(b, 5))
        sb = " ".join(str(x) for x in bits(total, 6))
        rows.append(f"{ab} {bb} {sb}")
write_vec("tests_adder5.vec", "A0 A1 A2 A3 A4 B0 B1 B2 B3 B4 S0 S1 S2 S3 S4 S5", rows)

# ---- cmp3: p1,p0,q1,q0 -> Eq (exhaustive 16) ---------------------------
rows = []
for p in range(4):
    for q in range(4):
        eq = 1 if (p % 3) == (q % 3) else 0
        p1, p0 = (p >> 1) & 1, p & 1
        q1, q0 = (q >> 1) & 1, q & 1
        rows.append(f"{p1} {p0} {q1} {q0} {eq}")
write_vec("tests_cmp3.vec", "p1 p0 q1 q0 Eq", rows)

# ---- eq5: A0..A4,B0..B4 -> Eq (exhaustive 1024) ------------------------
rows = []
for a in range(32):
    for b in range(32):
        eq = 1 if a == b else 0
        ab = " ".join(str(x) for x in bits(a, 5))
        bb = " ".join(str(x) for x in bits(b, 5))
        rows.append(f"{ab} {bb} {eq}")
write_vec("tests_eq5.vec", "A0 A1 A2 A3 A4 B0 B1 B2 B3 B4 Eq", rows)

# ---- mod3_checker / mod11_checker: exhaustive over all 10000 BCD values ----
rows3, rows11 = [], []
for n in range(10000):
    d0, d1, d2, d3 = n % 10, (n // 10) % 10, (n // 100) % 10, (n // 1000) % 10
    out3 = 1 if n % 3 == 0 else 0
    out11 = 1 if n % 11 == 0 else 0
    rows3.append(f"0x{d0:X} 0x{d1:X} 0x{d2:X} 0x{d3:X} {out3}")
    rows11.append(f"0x{d0:X} 0x{d1:X} 0x{d2:X} 0x{d3:X} {out11}")
write_vec("tests_mod3_checker_exhaustive.vec", "D0[4] D1[4] D2[4] D3[4] out", rows3)
write_vec("tests_mod11_checker_exhaustive.vec", "D0[4] D1[4] D2[4] D3[4] out", rows11)

# ---- small representative subset for quick sanity checks --------------
sample = [0, 1, 2, 3, 9, 10, 11, 12, 22, 33, 99, 100, 101, 111, 121, 132,
          198, 231, 330, 999, 1001, 1011, 1100, 1111, 2002, 3003, 4004,
          4995, 4996, 5005, 5500, 6666, 7777, 8712, 9999]
rows3s = []
rows11s = []
for n in sample:
    d0, d1, d2, d3 = n % 10, (n // 10) % 10, (n // 100) % 10, (n // 1000) % 10
    out3 = 1 if n % 3 == 0 else 0
    out11 = 1 if n % 11 == 0 else 0
    rows3s.append(f"0x{d0:X} 0x{d1:X} 0x{d2:X} 0x{d3:X} {out3}")
    rows11s.append(f"0x{d0:X} 0x{d1:X} 0x{d2:X} 0x{d3:X} {out11}")
write_vec("tests_mod3_checker.vec", "D0[4] D1[4] D2[4] D3[4] out", rows3s)
write_vec("tests_mod11_checker.vec", "D0[4] D1[4] D2[4] D3[4] out", rows11s)

# ---- main: both checkers together, random sample -----------------------
import random
random.seed(0)
main_sample = random.sample(range(10000), 40)
rows_main = []
for n in main_sample:
    d0, d1, d2, d3 = n % 10, (n // 10) % 10, (n // 100) % 10, (n // 1000) % 10
    out3 = 1 if n % 3 == 0 else 0
    out11 = 1 if n % 11 == 0 else 0
    rows_main.append(f"0x{d0:X} 0x{d1:X} 0x{d2:X} 0x{d3:X} {out3} {out11}")
write_vec("tests_main.vec", "D0[4] D1[4] D2[4] D3[4] mult_of_3 mult_of_11", rows_main)
