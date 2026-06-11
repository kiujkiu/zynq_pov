import fitz
doc = fitz.open(r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf')
print(f'pages = {len(doc)}')
for i in range(len(doc)):
    txt = doc[i].get_text()
    if 'GPIO1' in txt or 'J1' in txt or 'AA13' in txt or 'Y14' in txt or 'Y13' in txt:
        print(f'\n=== page {i+1} (has GPIO1/J1 keywords) ===')
        print(txt[:3000])
