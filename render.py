import zlib, re, sys, pathlib, requests, subprocess
from pathlib import Path
from server import server
def encode6bit(b):
    if b < 10: return chr(48 + b)
    b -= 10
    if b < 26: return chr(65 + b)
    b -= 26
    if b < 26: return chr(97 + b)
    b -= 26
    return ['-','_'][b]

def append3bytes(b1, b2, b3):
    c1 = (b1 >> 2) & 0x3F
    c2 = ((b1 & 0x3) << 4) | ((b2 >> 4) & 0xF)
    c3 = ((b2 & 0xF) << 2) | ((b3 >> 6) & 0x3)
    c4 = b3 & 0x3F
    return "".join([encode6bit(c1), encode6bit(c2), encode6bit(c3), encode6bit(c4)])

def encode64(data: bytes) -> str:
    res = ""
    for i in range(0, len(data), 3):
        if i+2 == len(data):
            res += append3bytes(data[i], data[i+1], 0)
        elif i+1 == len(data):
            res += append3bytes(data[i], 0, 0)
        else:
            res += append3bytes(data[i], data[i+1], data[i+2])
    return res

def encode_plantuml(text: str) -> str:
    # PlantUML expects raw DEFLATE (no zlib header/footer). This achieves that:
    data = zlib.compress(text.encode("utf-8"))
    data = data[2:-4]  # strip zlib header & Adler-32
    return encode64(data)

def extract_plantuml(md: str) -> str:
    # 1) \begin{plantuml}...\end{plantuml}
    m = re.search(r"\\begin\{plantuml\}(.*?)\\end\{plantuml\}", md, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()

    # 2) ```plantuml ... ``` or ```uml ... ```
    m = re.search(r"```(?:plantuml|uml)\s*(.*?)```", md, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()

    # 3) Fallback: assume the whole file is UML
    return md.strip()


def md_to_png(md_file: str):
    md_path = pathlib.Path(md_file)
    md = md_path.read_text(encoding="utf-8")

    uml_text = extract_plantuml(md)
    if not uml_text:
        sys.exit("No PlantUML block found.")

    print("=== Extracted UML ===")
    print(uml_text)

    encoded = encode_plantuml(uml_text)

    url = f"{server}{encoded}"
    print("=== URL ===")
    print(url)

    response = requests.get(url)
    if response.status_code == 200:
        png_file = md_path.with_suffix(".png")
        with open(png_file, "wb") as f:
            f.write(response.content)
        print("Saved as", png_file)
    else:
        print("Error:", response.status_code)


if __name__ == "__main__":
    folder = pathlib.Path("./")  # current folder
    for md_file in Path(".").rglob("*.md"):
        md_to_png(md_file)