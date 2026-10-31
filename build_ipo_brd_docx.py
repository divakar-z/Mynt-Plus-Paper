"""Convert WEB_IPO_BRD.md into a styled .docx.

Transforms each test case (### IPO-xxx) into the canonical 2-column
Field | Detail table so the docx matches the shipped BRD visual style
(blue header rows, alternating shading), then post-processes with
python-docx like the Holdings BRD build.
"""
import re
from pathlib import Path

import pypandoc
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.table import WD_ALIGN_VERTICAL

ROOT = Path(__file__).parent
MD_PATH = ROOT / "WEB_IPO_BRD.md"


def first_unlocked(base: Path) -> Path:
    candidates = [base] + [
        base.with_name(f"{base.stem}_v{i}{base.suffix}") for i in range(2, 10)
    ]
    for p in candidates:
        try:
            with open(p, "ab"):
                pass
            return p
        except PermissionError:
            continue
    raise SystemExit("All candidate output names are locked — close Word.")


DOCX_PATH = first_unlocked(ROOT / "WEB_IPO_BRD.docx")
if DOCX_PATH.name != "WEB_IPO_BRD.docx":
    print(f"WARNING: target locked; writing {DOCX_PATH.name} instead")

PRIMARY = "1F3A93"
WHITE = "FFFFFF"
# Plain-text marker converted to a real Word line break in post-processing.
BR_MARKER = "ZZBRKZZ"

md_text = MD_PATH.read_text(encoding="utf-8")

# Flatten repo-relative markdown links (file:line refs) to inline code.
md_text = re.sub(r"\[([^\]]+)\]\((?:lib|web)[^)]*\)", r"`\1`", md_text)


def cell_safe(text: str) -> str:
    """Make a block of markdown safe inside a single pipe-table cell."""
    text = text.replace("|", "\\|")
    return " ".join(text.split())


def list_to_cell(block: str, numbered: bool) -> str:
    """Render list items inside a pipe-table cell, one item per line.

    Pipe-table cells cannot contain raw newlines, but pandoc converts
    inline ``<br>`` into real line breaks in the .docx cell.
    """
    items = []
    current: list[str] = []
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if re.match(r"^(\d+\.)\s+", stripped) or stripped.startswith(("- ", "* ")):
            if current:
                items.append(" ".join(current))
            current = [re.sub(r"^(\d+\.\s+|-\s+|\*\s+)", "", stripped)]
        else:
            current.append(stripped)
    if current:
        items.append(" ".join(current))
    if numbered:
        return BR_MARKER.join(
            f"{i + 1}. {cell_safe(it)}" for i, it in enumerate(items)
        )
    return BR_MARKER.join(f"• {cell_safe(it)}" for it in items)


def convert_case(case_md: str) -> str:
    """Convert one `### IPO-xxx — title` case block to a 2-column table."""
    lines = case_md.splitlines()
    title = lines[0].lstrip("# ").strip()
    body = "\n".join(lines[1:])

    # Split the body into labelled segments by the bold field markers.
    seg_re = re.compile(
        r"\*\*(Status|Description|Test Steps|Expected Result):\*\*", re.M
    )
    parts = seg_re.split(body)
    # parts: [before, label1, text1, label2, text2, ...]
    fields: dict[str, str] = {}
    for i in range(1, len(parts) - 1, 2):
        fields[parts[i]] = parts[i + 1].strip()

    desc = fields.get("Description", "")
    steps = fields.get("Test Steps", "")
    expected = fields.get("Expected Result", "")

    # Anything in Expected Result after the bullet list that starts a new
    # paragraph (e.g. API notes / formatting notes) stays in the same cell.
    rows = []
    if fields.get("Status"):
        rows.append(("**Status**", cell_safe(fields["Status"])))
    rows += [
        ("**Description**", cell_safe(desc)),
        ("**Test Steps**", list_to_cell(steps, numbered=True)),
        ("**Expected Result**", list_to_cell(expected, numbered=False)),
    ]
    table = "| Field | Detail |\n|---|---|\n"
    table += "\n".join(f"| {k} | {v} |" for k, v in rows)
    return f"#### {title}\n\n{table}"


# Split the document on case headings and convert each case block.
chunks = re.split(r"(?=^### IPO-)", md_text, flags=re.M)
converted = [chunks[0]]
for chunk in chunks[1:]:
    # A chunk runs until the next case or section heading; keep any trailing
    # non-case content (---, ## headings) outside the table conversion.
    m = re.match(r"(.*?)(\n(?:---|## |# ).*)?$", chunk, re.DOTALL)
    case_part, rest = m.group(1), m.group(2) or ""
    converted.append(convert_case(case_part.strip()) + "\n" + rest)
md_text = "".join(converted)

# Document Control cover table from the metadata block.
md_text = re.sub(
    r"# Web — IPO BRD\n\n"
    r"\*\*Module:\*\* ([^\n]+)\n"
    r"\*\*Platform:\*\* ([^\n]+)\n"
    r"\*\*Owner:\*\* ([^\n]+)\n"
    r"\*\*Last updated:\*\* ([^\n]+)\n",
    lambda m: (
        "# IPO — Business Requirements Document\n\n"
        "## Document Control\n\n"
        "| Field | Detail |\n|---|---|\n"
        "| **Document Title** | IPO — Business Requirements Document |\n"
        "| **Product** | Mynt Plus — Web Trading Platform |\n"
        f"| **Module** | {m.group(1)} |\n"
        f"| **Platform** | {m.group(2)} |\n"
        f"| **Owner** | {m.group(3)} |\n"
        f"| **Last updated** | {m.group(4)} |\n"
        "| **Status** | Issued for Review |\n"
        "| **Classification** | Internal Use Only |\n"
    ),
    md_text,
)

print("Running pandoc...")
pypandoc.convert_text(
    md_text,
    "docx",
    format="markdown+pipe_tables+raw_html+fenced_code_blocks",
    outputfile=str(DOCX_PATH),
    extra_args=["--standalone", "--toc", "--toc-depth=2"],
)

doc = Document(str(DOCX_PATH))


def shade(cell, c):
    p = cell._tc.get_or_add_tcPr()
    s = OxmlElement("w:shd")
    s.set(qn("w:val"), "clear")
    s.set(qn("w:color"), "auto")
    s.set(qn("w:fill"), c)
    p.append(s)


def colour(cell, c):
    for para in cell.paragraphs:
        for r in para.runs:
            r.font.color.rgb = RGBColor.from_string(c)


def bold(cell):
    for para in cell.paragraphs:
        for r in para.runs:
            r.bold = True


def header_repeat(row):
    tp = row._tr.get_or_add_trPr()
    h = OxmlElement("w:tblHeader")
    h.set(qn("w:val"), "true")
    tp.append(h)


def marker_to_linebreaks(cell):
    """Replace BR_MARKER occurrences inside runs with real <w:br/> breaks."""
    for para in cell.paragraphs:
        for run in para.runs:
            if BR_MARKER not in run.text:
                continue
            parts = run.text.split(BR_MARKER)
            r = run._r
            for t in r.findall(qn("w:t")):
                r.remove(t)
            for i, part in enumerate(parts):
                if i > 0:
                    r.append(OxmlElement("w:br"))
                t = OxmlElement("w:t")
                t.set(qn("xml:space"), "preserve")
                t.text = part
                r.append(t)


for table in doc.tables:
    if not table.rows:
        continue
    for cell in table.rows[0].cells:
        shade(cell, PRIMARY)
        colour(cell, WHITE)
        bold(cell)
    header_repeat(table.rows[0])
    for i, row in enumerate(table.rows[1:]):
        for j, cell in enumerate(row.cells):
            if i % 2 == 1:
                shade(cell, "F7F8FC")
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            marker_to_linebreaks(cell)

for name, size in [
    ("Title", Pt(28)),
    ("Heading 1", Pt(20)),
    ("Heading 2", Pt(15)),
    ("Heading 3", Pt(12.5)),
    ("Heading 4", Pt(11)),
]:
    try:
        st = doc.styles[name]
        st.font.color.rgb = RGBColor.from_string(PRIMARY)
        st.font.size = size
        st.font.bold = True
    except KeyError:
        pass

for s in doc.sections:
    s.top_margin = Cm(1.8)
    s.bottom_margin = Cm(2.2)
    s.left_margin = Cm(1.6)
    s.right_margin = Cm(1.6)

doc.save(str(DOCX_PATH))
print(f"Wrote {DOCX_PATH} ({DOCX_PATH.stat().st_size // 1024} KB)")
