import sys, re
try:
    import pypdf
    reader = pypdf.PdfReader(sys.argv[1])
except ImportError:
    from PyPDF2 import PdfReader
    reader = PdfReader(sys.argv[1])
# Extract Page 6 (which has BANK 33 + BANK 35 site → pin)
page = reader.pages[5]  # 0-indexed
text = page.extract_text()
# Find all IO_LxN/P_T_x_35 followed by package pin
patterns = re.findall(r'(IO_L\d+[NP]_T\d_[^_\s]*(?:_AD\d+[NP])?_35)\s*(\w?\d+)', text)
print(f"BANK 35 site → pin entries: {len(patterns)}")
for site, pin in patterns:
    print(f"  {site} → {pin}")
# Also dump raw text around BANK 35 markers
idx = text.find('BANK 35')
if idx >= 0:
    print("\n=== raw around BANK 35 ===")
    print(text[idx:idx+3000])
