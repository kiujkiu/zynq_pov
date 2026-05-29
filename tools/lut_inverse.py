"""Build inverse mapping helpers from calib_lut.json + calib_p2_lut.json.

Phase 1 LUT  : (chain, chip, bit) → list of (cx_pct, cy_pct, area)   [physical LED locations]
Phase 2 LUT  : row_iter → (cx_pct, cy_pct, area)                     [row → y mapping]

Inverse functions:
  led_pixels()           → flat list of (cx, cy, chain, chip, bit) for every detected LED
  nearest_led(x, y)      → (chain, chip, bit, dist) for the closest LED to a target pixel
  row_iter_for_y(y_pct)  → row_iter whose y_pct is closest

Usage:
    from lut_inverse import load_inverse
    inv = load_inverse()
    print(inv.nearest_led(50, 50))
    print(inv.row_iter_for_y(50))
"""
import json, os
from dataclasses import dataclass, field

@dataclass
class Inverse:
    leds: list = field(default_factory=list)         # [(cx, cy, chain, chip, bit, area), ...]
    row_map: list = field(default_factory=list)      # [(row_iter, cy_pct), ...] sorted by row

    def nearest_led(self, x_pct, y_pct):
        if not self.leds:
            return None
        best = min(self.leds, key=lambda p: (p[0]-x_pct)**2 + (p[1]-y_pct)**2)
        cx, cy, c, k, b, _ = best
        dist = ((cx-x_pct)**2 + (cy-y_pct)**2) ** 0.5
        return dict(chain=c, chip=k, bit=b, cx=cx, cy=cy, dist=dist)

    def row_iter_for_y(self, y_pct):
        if not self.row_map:
            return None
        r, _ = min(self.row_map, key=lambda rc: abs(rc[1] - y_pct))
        return r

def load_inverse(p1_path=r"D:\workspace\zynq_pov\tools\calib_out\calib_lut.json",
                 p2_path=r"D:\workspace\zynq_pov\tools\calib_out\calib_p2_lut.json"):
    inv = Inverse()
    if os.path.exists(p1_path):
        p1 = json.load(open(p1_path))
        for rec in p1.values():
            for bl in rec["blobs"]:
                inv.leds.append((bl["cx_pct"], bl["cy_pct"],
                                 rec["chain"], rec["chip"], rec["bit"], bl["area"]))
        print(f"loaded P1: {len(inv.leds)} LED points from {len(p1)} tuples")
    if os.path.exists(p2_path):
        p2 = json.load(open(p2_path))
        inv.row_map = sorted((v["row_iter"], v["cy_pct"]) for v in p2.values())
        print(f"loaded P2: {len(inv.row_map)} row_iter→y entries")
    return inv

if __name__ == "__main__":
    inv = load_inverse()
    if inv.leds:
        # spot-check 4 corners + center
        for tx, ty in [(10, 10), (90, 10), (50, 50), (10, 90), (90, 90)]:
            r = inv.nearest_led(tx, ty)
            print(f"  ({tx:2d},{ty:2d}) → C{r['chain']} K{r['chip']:02d} B{r['bit']:02d} "
                  f"@ ({r['cx']:.1f},{r['cy']:.1f}) dist={r['dist']:.1f}")
    if inv.row_map:
        for ty in [10, 30, 50, 70, 90]:
            print(f"  y={ty:2d}% → row_iter={inv.row_iter_for_y(ty)}")
