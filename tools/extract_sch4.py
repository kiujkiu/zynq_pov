import sys
try:
    import pypdf
    reader = pypdf.PdfReader(sys.argv[1])
except ImportError:
    from PyPDF2 import PdfReader
    reader = PdfReader(sys.argv[1])
page = reader.pages[5]  # page 6
text = page.extract_text()
# Just dump full text
print(text)
