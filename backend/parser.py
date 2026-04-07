import pdfplumber

def parse_resume(file_bytes):
    with open("resume.pdf", "wb") as f:
        f.write(file_bytes)

    text = ""
    with pdfplumber.open("resume.pdf") as pdf:
        for page in pdf.pages:
            text += page.extract_text() or ""

    return text[:5000]