import fitz, re
doc = fitz.open(r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf')
page = doc[7]
blocks = page.get_text("dict")
items = []
for block in blocks['blocks']:
    if 'lines' not in block: continue
    for line in block['lines']:
        for span in line['spans']:
            txt = span['text'].strip()
            if not txt: continue
            bbox = span['bbox']
            cx = (bbox[0]+bbox[2])/2
            cy = (bbox[1]+bbox[3])/2
            items.append((cx, cy, txt))

# Group by Y bands (3-pixel tolerance), find rows with both pin number and IO net in GPIO1 area (x<600)
rows = {}
for cx, cy, txt in items:
    if cx > 600: continue  # skip GPIO2
    key = round(cy/4)*4  # 4-px bins
    rows.setdefault(key, []).append((cx, txt))

# print rows that have pin numbers and IO_L nets
print("== GPIO1 pin <-> net mapping (extracted from schematic) ==")
print(f"{'pin':>5} {'net':<28}  {'pin':>5} {'net':<28}")
for y in sorted(rows):
    items_in_row = sorted(rows[y])
    nets = [(cx,txt) for cx,txt in items_in_row if 'IO_L' in txt]
    pins = [(cx,txt) for cx,txt in items_in_row if re.fullmatch(r'\d+', txt) and int(txt)<=40]
    if not (nets and pins): continue
    # left pin (small x) + left net (small x); right pin + right net
    left_net = nets[0][1] if nets else ""
    right_net = nets[-1][1] if len(nets)>1 else ""
    # take unique pin numbers
    pin_vals = sorted(set([int(t) for _,t in pins]))
    if len(pin_vals) >= 2:
        print(f"{pin_vals[0]:>5} {left_net:<28}  {pin_vals[1]:>5} {right_net:<28}")
    elif len(pin_vals) == 1:
        print(f"{pin_vals[0]:>5} {left_net:<28}")
