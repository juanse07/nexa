"""PDF report generation using WeasyPrint (HTML→PDF) with Jinja2 templates."""

from __future__ import annotations

import os
from datetime import datetime, timezone

import markdown
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML

from app.models.schemas import ReportRequest, ReportType

_TEMPLATE_DIR = os.path.join(os.path.dirname(__file__), "..", "templates")
_env = Environment(loader=FileSystemLoader(_TEMPLATE_DIR), autoescape=True)


def _build_staff_shifts_context(req: ReportRequest) -> dict:
    columns = [
        {"key": "date", "label": "Date", "align": "left"},
        {"key": "eventName", "label": "Event", "align": "left"},
        {"key": "clientName", "label": "Client", "align": "left"},
        {"key": "venueName", "label": "Venue", "align": "left"},
        {"key": "role", "label": "Role", "align": "left"},
        {"key": "clockIn", "label": "Clock In", "align": "left"},
        {"key": "clockOut", "label": "Clock Out", "align": "left"},
        {"key": "hoursWorked", "label": "Hours", "align": "right"},
        {"key": "hourlyRate", "label": "Rate", "align": "right"},
        {"key": "earnings", "label": "Earnings", "align": "right"},
    ]
    summary_items = [
        {"label": "Total Shifts", "value": req.summary.get("totalShifts", len(req.records))},
        {"label": "Total Hours", "value": req.summary.get("totalHours", 0)},
        {"label": "Total Earnings", "value": f"${req.summary.get('totalEarnings', 0):,.2f}"},
    ]
    totals = {
        "date": "TOTAL",
        "hoursWorked": req.summary.get("totalHours", 0),
        "earnings": f"${req.summary.get('totalEarnings', 0):,.2f}",
    }
    # Format earnings in rows
    rows = []
    for r in req.records:
        row = dict(r)
        row["earnings"] = f"${row.get('earnings', 0):,.2f}"
        row["hourlyRate"] = f"${row.get('hourlyRate', 0):,.2f}"
        rows.append(row)
    return {"columns": columns, "rows": rows, "summary_items": summary_items, "totals": totals}


def _build_payroll_context(req: ReportRequest) -> dict:
    columns = [
        {"key": "name", "label": "Staff Name", "align": "left"},
        {"key": "email", "label": "Email", "align": "left"},
        {"key": "shifts", "label": "Shifts", "align": "right"},
        {"key": "hours", "label": "Hours", "align": "right"},
        {"key": "averageRate", "label": "Avg Rate", "align": "right"},
        {"key": "totalPay", "label": "Total Pay", "align": "right"},
    ]
    summary_items = [
        {"label": "Staff Count", "value": req.summary.get("staffCount", len(req.records))},
        {"label": "Total Hours", "value": req.summary.get("totalHours", 0)},
        {"label": "Total Payroll", "value": f"${req.summary.get('totalPayroll', 0):,.2f}"},
    ]
    totals = {
        "name": "TOTAL",
        "shifts": sum(r.get("shifts", 0) for r in req.records),
        "hours": req.summary.get("totalHours", 0),
        "totalPay": f"${req.summary.get('totalPayroll', 0):,.2f}",
    }
    rows = []
    for r in req.records:
        row = dict(r)
        row["averageRate"] = f"${row.get('averageRate', 0):,.2f}"
        row["totalPay"] = f"${row.get('totalPay', 0):,.2f}"
        rows.append(row)
    return {"columns": columns, "rows": rows, "summary_items": summary_items, "totals": totals}


def _build_attendance_context(req: ReportRequest) -> dict:
    columns = [
        {"key": "date", "label": "Date", "align": "left"},
        {"key": "eventName", "label": "Event", "align": "left"},
        {"key": "staffName", "label": "Staff", "align": "left"},
        {"key": "role", "label": "Role", "align": "left"},
        {"key": "scheduledStart", "label": "Sched. Start", "align": "left"},
        {"key": "scheduledEnd", "label": "Sched. End", "align": "left"},
        {"key": "clockIn", "label": "Clock In", "align": "left"},
        {"key": "clockOut", "label": "Clock Out", "align": "left"},
        {"key": "hoursWorked", "label": "Hours", "align": "right"},
        {"key": "status", "label": "Status", "align": "left"},
    ]
    summary_items = [
        {"label": "Total Records", "value": req.summary.get("totalRecords", len(req.records))},
        {"label": "Total Hours", "value": req.summary.get("totalHours", 0)},
    ]
    totals = {
        "date": "TOTAL",
        "hoursWorked": req.summary.get("totalHours", 0),
    }
    return {"columns": columns, "rows": req.records, "summary_items": summary_items, "totals": totals}


_CONTEXT_BUILDERS = {
    ReportType.STAFF_SHIFTS: _build_staff_shifts_context,
    ReportType.PAYROLL: _build_payroll_context,
    ReportType.ATTENDANCE: _build_attendance_context,
}


def _build_ai_analysis_context(req: ReportRequest) -> dict:
    """Build context for AI analysis reports — renders markdown content to HTML."""
    md_text = ""
    if req.records and len(req.records) > 0:
        md_text = req.records[0].get("content", "")

    analysis_html = markdown.markdown(md_text, extensions=["tables", "fenced_code"])

    summary_items = []
    if req.summary:
        if "totalEvents" in req.summary:
            summary_items.append({"label": "Events", "value": req.summary["totalEvents"]})
        if "totalStaffHours" in req.summary:
            summary_items.append({"label": "Staff Hours", "value": req.summary["totalStaffHours"]})
        if "totalPayroll" in req.summary:
            summary_items.append({"label": "Payroll", "value": f"${req.summary['totalPayroll']:,.2f}"})
        if "fulfillmentRate" in req.summary:
            summary_items.append({"label": "Fulfillment", "value": f"{req.summary['fulfillmentRate']}%"})

    return {"analysis_html": analysis_html, "summary_items": summary_items}


def create_report(req: ReportRequest, output_path: str) -> None:
    # AI analysis uses a different template
    if req.report_type == ReportType.AI_ANALYSIS:
        ctx = _build_ai_analysis_context(req)
        ctx.update(
            {
                "title": req.title,
                "company_name": req.company_name,
                "period_label": req.period.label,
                "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
            }
        )
        template = _env.get_template("analysis.html")
        html_str = template.render(**ctx)
        HTML(string=html_str).write_pdf(output_path)
        return

    builder = _CONTEXT_BUILDERS.get(req.report_type)
    if not builder:
        raise ValueError(f"Unknown report type: {req.report_type}")

    ctx = builder(req)
    ctx.update(
        {
            "title": req.title,
            "company_name": req.company_name,
            "period_label": req.period.label,
            "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        }
    )

    template = _env.get_template("report.html")
    html_str = template.render(**ctx)
    HTML(string=html_str).write_pdf(output_path)
