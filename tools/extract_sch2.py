import sys
try:
    import pypdf
    reader = pypdf.PdfReader(sys.argv[1])
except ImportError:
    from PyPDF2 import PdfReader
    reader = PdfReader(sys.argv[1])
# Output all pages content briefly
for i, page in enumerate(reader.pages):
    text = page.extract_text()
    head = (text[:300] or "").replace("\n", " ")[:200]
    print(f"=== Page {i+1}: {head}")
