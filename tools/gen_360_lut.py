"""Generate cos/sin 360-entry tables (Q8.8, 256*cos/sin per degree)."""
import math
print("static const int16_t cos360_table[360] = {")
for i in range(0, 360, 10):
    row = [int(round(256 * math.cos(math.radians(d)))) for d in range(i, i + 10)]
    print("    " + ", ".join(f"{v:>4}" for v in row) + ",")
print("};")
print("static const int16_t sin360_table[360] = {")
for i in range(0, 360, 10):
    row = [int(round(256 * math.sin(math.radians(d)))) for d in range(i, i + 10)]
    print("    " + ", ".join(f"{v:>4}" for v in row) + ",")
print("};")
