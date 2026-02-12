"""Word document (.docx) generation using python-docx."""

from __future__ import annotations

from datetime import datetime, timezone

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt, RGBColor

from app.models.schemas import ReportRequest, ReportType

_HEADER_BG = RGBColor(0x1E, 0x29, 0x3B)
_HEADER_FG = RGBColor(0xFF, 0xFF, 0xFF)
_ALT_ROW_BG = RGBColor(0xF8, 0xFA, 0xFC)
_BORDER_COLOR = RGBColor(0xCB, 0xD5, 0xE1)


def _set_cell_shading(cell, color: RGBColor):
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn

    shading = OxmlElement("w:shd")
    shading.set(qn("w:fill"), str(color))
    shading.set(qn("w:val"), "clear")
    cell._tc.get_or_add_tcPr().append(shading)


def _style_header_row(row, columns: list[str]):
    for i, cell in enumerate(row.cells):
        cell.text = columns[i]
        for p in cell.paragraphs:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            for run in p.runs:
                run.font.bold = True
                run.font.size = Pt(9)
                run.font.color.rgb = _HEADER_FG
        _set_cell_shading(cell, _HEADER_BG)


def _add_data_row(table, values: list[str], row_idx: int):
    row = table.add_row()
    for i, cell in enumerate(row.cells):
        cell.text = str(values[i])
        for p in cell.paragraphs:
            for run in p.runs:
                run.font.size = Pt(9)
    if row_idx % 2 == 0:
        for cell in row.cells:
            _set_cell_shading(cell, _ALT_ROW_BG)
    return row


def _add_summary_section(doc: Document, items: list[tuple[str, str]]):
    doc.add_paragraph()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = p.add_run("Summary")
    run.font.size = Pt(13)
    run.font.bold = True
    run.font.color.rgb = _HEADER_BG

    for label, value in items:
        p = doc.add_paragraph()
        run_label = p.add_run(f"{label}: ")
        run_label.font.bold = True
        run_label.font.size = Pt(10)
        run_val = p.add_run(str(value))
        run_val.font.size = Pt(10)


def _build_staff_shifts(doc: Document, req: ReportRequest):
    cols = ["Date", "Event", "Client", "Venue", "Role", "Clock In", "Clock Out", "Hours", "Rate", "Earnings"]
    table = doc.add_table(rows=1, cols=len(cols))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    _style_header_row(table.rows[0], cols)

    for idx, r in enumerate(req.records):
        _add_data_row(
            table,
            [
                r.get("date", ""),
                r.get("eventName", ""),
                r.get("clientName", ""),
                r.get("venueName", ""),
                r.get("role", ""),
                r.get("clockIn", ""),
                r.get("clockOut", ""),
                str(r.get("hoursWorked", 0)),
                f"${r.get('hourlyRate', 0):,.2f}",
                f"${r.get('earnings', 0):,.2f}",
            ],
            idx,
        )

    _add_summary_section(
        doc,
        [
            ("Total Shifts", str(req.summary.get("totalShifts", len(req.records)))),
            ("Total Hours", str(req.summary.get("totalHours", 0))),
            ("Total Earnings", f"${req.summary.get('totalEarnings', 0):,.2f}"),
        ],
    )


def _build_payroll(doc: Document, req: ReportRequest):
    cols = ["Staff Name", "Email", "Shifts", "Hours", "Avg Rate", "Total Pay"]
    table = doc.add_table(rows=1, cols=len(cols))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    _style_header_row(table.rows[0], cols)

    for idx, r in enumerate(req.records):
        _add_data_row(
            table,
            [
                r.get("name", ""),
                r.get("email", ""),
                str(r.get("shifts", 0)),
                str(r.get("hours", 0)),
                f"${r.get('averageRate', 0):,.2f}",
                f"${r.get('totalPay', 0):,.2f}",
            ],
            idx,
        )

    _add_summary_section(
        doc,
        [
            ("Staff Count", str(req.summary.get("staffCount", len(req.records)))),
            ("Total Hours", str(req.summary.get("totalHours", 0))),
            ("Total Payroll", f"${req.summary.get('totalPayroll', 0):,.2f}"),
        ],
    )


def _build_attendance(doc: Document, req: ReportRequest):
    cols = ["Date", "Event", "Staff", "Role", "Sched. Start", "Sched. End", "Clock In", "Clock Out", "Hours", "Status"]
    table = doc.add_table(rows=1, cols=len(cols))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    _style_header_row(table.rows[0], cols)

    for idx, r in enumerate(req.records):
        _add_data_row(
            table,
            [
                r.get("date", ""),
                r.get("eventName", ""),
                r.get("staffName", ""),
                r.get("role", ""),
                r.get("scheduledStart", ""),
                r.get("scheduledEnd", ""),
                r.get("clockIn", ""),
                r.get("clockOut", ""),
                str(round(r.get("hoursWorked", 0), 1)),
                r.get("status", ""),
            ],
            idx,
        )

    _add_summary_section(
        doc,
        [
            ("Total Records", str(req.summary.get("totalRecords", len(req.records)))),
            ("Total Hours", str(req.summary.get("totalHours", 0))),
        ],
    )


_BUILDERS = {
    ReportType.STAFF_SHIFTS: _build_staff_shifts,
    ReportType.PAYROLL: _build_payroll,
    ReportType.ATTENDANCE: _build_attendance,
}


def create_report(req: ReportRequest, output_path: str) -> None:
    builder = _BUILDERS.get(req.report_type)
    if not builder:
        raise ValueError(f"Unknown report type: {req.report_type}")

    doc = Document()

    # Title
    title_para = doc.add_heading(req.title, level=1)
    for run in title_para.runs:
        run.font.color.rgb = _HEADER_BG

    # Subtitle with period
    subtitle = doc.add_paragraph()
    run = subtitle.add_run(f"{req.company_name}  |  {req.period.label}")
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(0x64, 0x74, 0x8B)

    doc.add_paragraph()

    builder(doc, req)

    # Footer
    doc.add_paragraph()
    footer = doc.add_paragraph()
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run(
        f"Generated by {req.company_name} Document Service — "
        f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}"
    )
    run.font.size = Pt(8)
    run.font.color.rgb = RGBColor(0x94, 0xA3, 0xB8)

    doc.save(output_path)
