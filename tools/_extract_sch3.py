import fitz, re
doc = fitz.open(r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf')
page = doc[7]  # page 8

# get text with positions
blocks = page.get_text("dict")
# collect all text items with coordinates
items = []
for block in blocks['blocks']:
    if 'lines' not in block:
        continue
    for line in block['lines']:
        for span in line['spans']:
            txt = span['text'].strip()
            if not txt:
                continue
            bbox = span['bbox']  # (x0,y0,x1,y1)
            cx = (bbox[0]+bbox[2])/2
            cy = (bbox[1]+bbox[3])/2
            items.append((cx, cy, txt))

# find GPIO1 connector area: look for "GPIO1" label
gpio1_pos = [it for it in items if it[2]=='GPIO1']
print(f"GPIO1 label at: {gpio1_pos}")

# look for nets near each pin number 1-40 in the GPIO1 connector
# Group items by approximate Y coordinate (pin rows)
# Pin numbers in GPIO1 area
pin_candidates = [it for it in items if re.fullmatch(r'\d+', it[2]) and int(it[2])<=40]

# Print GPIO1 connector content: items in a band around gpio1_pos Y
if gpio1_pos:
    gx, gy, _ = gpio1_pos[0]
    print(f"GPIO1 anchor x={gx} y={gy}")
    # show all items within 400 px of GPIO1
    near = [it for it in items if abs(it[1]-gy)<400 and abs(it[0]-gx)<400]
    near.sort(key=lambda it: (it[1], it[0]))
    for cx, cy, txt in near:
        if 'IO_L' in txt or re.fullmatch(r'\d+', txt) or 'BANK' in txt:
            print(f"  ({cx:.0f},{cy:.0f}) {txt}")
