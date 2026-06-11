import fitz
doc = fitz.open(r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf')
for i in range(len(doc)):
    txt = doc[i].get_text()
    # look for pages with GPIO1 connector references
    if 'GPIO1' in txt or 'GPIO_1' in txt:
        print(f'\n========== page {i+1} ==========')
        print(txt)
        print(f'========== end page {i+1} ==========\n')
