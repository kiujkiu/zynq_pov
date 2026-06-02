import sys
try:
    import pypdf
    reader = pypdf.PdfReader(sys.argv[1])
except ImportError:
    from PyPDF2 import PdfReader
    reader = PdfReader(sys.argv[1])
for i, page in enumerate(reader.pages):
    text = page.extract_text()
    if 'GPIO2' in text or 'BANK 35' in text or 'GPIO_2' in text or 'BANK35' in text or 'gpio2' in text:
        print(f"=== Page {i+1} (has GPIO2/BANK35) ===")
        print(text[:3000])
        print("===")
