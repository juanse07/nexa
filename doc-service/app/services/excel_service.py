"""Excel spreadsheet generation using pandas + XlsxWriter."""

from __future__ import annotations

from datetime import datetime, timezone

import pandas as pd

from app.models.schemas import ReportRequest, ReportType


def _write_staff_shifts(req: ReportRequest, writer: pd.ExcelWriter):
    df = pd.DataFrame(req.records)
    col_map = {
        "date": "Date",
        "eventName": "Event",
        "clientName": "Client",
        "venueName": "Venue",
        "role": "Role",
        "clockIn": "Clock In",
        "clockOut": "Clock Out",
        "hoursWorked": "Hours",
        "hourlyRate": "Pay Rate",
        "earnings": "Earnings",
    }
    cols = [c for c in col_map if c in df.columns]
    df = df[cols].rename(columns=col_map)
    sheet = "Shift History"
    df.to_excel(writer, sheet_name=sheet, index=False, startrow=1)

    workbook = writer.book
    worksheet = writer.sheets[sheet]
    _write_title(workbook, worksheet, req.title, len(df.columns))
    _style_sheet(workbook, worksheet, df)

    # Summary row
    summary_row = len(df) + 3
    bold = workbook.add_format({"bold": True, "font_size": 11})
    money = workbook.add_format({"bold": True, "num_format": "$#,##0.00", "font_size": 11})
    worksheet.write(summary_row, 0, "TOTAL", bold)
    worksheet.write(summary_row, 7, req.summary.get("totalHours", 0), bold)
    worksheet.write(summary_row, 9, req.summary.get("totalEarnings", 0), money)

    # Chart
    if len(df) > 0 and len(df) <= 50:
        chart = workbook.add_chart({"type": "bar"})
        chart.add_series(
            {
                "name": "Earnings",
                "categories": [sheet, 2, 1, len(df) + 1, 1],
                "values": [sheet, 2, 9, len(df) + 1, 9],
            }
        )
        chart.set_title({"name": "Earnings by Event"})
        chart.set_style(10)
        worksheet.insert_chart(f"A{summary_row + 3}", chart, {"x_scale": 1.5, "y_scale": 1.2})


def _write_payroll(req: ReportRequest, writer: pd.ExcelWriter):
    df = pd.DataFrame(req.records)
    col_map = {
        "name": "Staff Name",
        "email": "Email",
        "shifts": "Shifts",
        "hours": "Hours",
        "averageRate": "Avg Rate",
        "totalPay": "Total Pay",
    }
    cols = [c for c in col_map if c in df.columns]
    df = df[cols].rename(columns=col_map)
    sheet = "Payroll Report"
    df.to_excel(writer, sheet_name=sheet, index=False, startrow=1)

    workbook = writer.book
    worksheet = writer.sheets[sheet]
    _write_title(workbook, worksheet, req.title, len(df.columns))
    _style_sheet(workbook, worksheet, df)

    # Summary
    summary_row = len(df) + 3
    bold = workbook.add_format({"bold": True, "font_size": 11})
    money = workbook.add_format({"bold": True, "num_format": "$#,##0.00", "font_size": 11})
    worksheet.write(summary_row, 0, "TOTAL", bold)
    worksheet.write(summary_row, 2, sum(r.get("shifts", 0) for r in req.records), bold)
    worksheet.write(summary_row, 3, req.summary.get("totalHours", 0), bold)
    worksheet.write(summary_row, 5, req.summary.get("totalPayroll", 0), money)

    # Chart
    if len(df) > 0 and len(df) <= 50:
        chart = workbook.add_chart({"type": "bar"})
        chart.add_series(
            {
                "name": "Total Pay",
                "categories": [sheet, 2, 0, len(df) + 1, 0],
                "values": [sheet, 2, 5, len(df) + 1, 5],
            }
        )
        chart.set_title({"name": "Pay by Staff Member"})
        chart.set_style(10)
        worksheet.insert_chart(f"A{summary_row + 3}", chart, {"x_scale": 1.5, "y_scale": 1.2})


def _write_attendance(req: ReportRequest, writer: pd.ExcelWriter):
    df = pd.DataFrame(req.records)
    col_map = {
        "date": "Date",
        "eventName": "Event",
        "staffName": "Staff",
        "role": "Role",
        "scheduledStart": "Sched. Start",
        "scheduledEnd": "Sched. End",
        "clockIn": "Clock In",
        "clockOut": "Clock Out",
        "hoursWorked": "Hours",
        "status": "Status",
    }
    cols = [c for c in col_map if c in df.columns]
    df = df[cols].rename(columns=col_map)
    sheet = "Attendance Report"
    df.to_excel(writer, sheet_name=sheet, index=False, startrow=1)

    workbook = writer.book
    worksheet = writer.sheets[sheet]
    _write_title(workbook, worksheet, req.title, len(df.columns))
    _style_sheet(workbook, worksheet, df)

    # Summary
    summary_row = len(df) + 3
    bold = workbook.add_format({"bold": True, "font_size": 11})
    worksheet.write(summary_row, 0, "TOTAL", bold)
    worksheet.write(summary_row, 8, req.summary.get("totalHours", 0), bold)


def _write_title(workbook, worksheet, title: str, num_cols: int):
    title_fmt = workbook.add_format(
        {
            "bold": True,
            "font_size": 14,
            "font_color": "#1E293B",
            "bottom": 2,
            "bottom_color": "#1E293B",
        }
    )
    worksheet.merge_range(0, 0, 0, num_cols - 1, title, title_fmt)


def _style_sheet(workbook, worksheet, df: pd.DataFrame):
    header_fmt = workbook.add_format(
        {
            "bold": True,
            "font_size": 10,
            "font_color": "#FFFFFF",
            "bg_color": "#1E293B",
            "border": 1,
            "border_color": "#CBD5E1",
            "text_wrap": True,
        }
    )
    # Write header row with format
    for col_num, col_name in enumerate(df.columns):
        worksheet.write(1, col_num, col_name, header_fmt)

    # Auto-fit column widths (approximate)
    for col_num, col_name in enumerate(df.columns):
        max_len = max(
            len(str(col_name)),
            df.iloc[:, col_num].astype(str).str.len().max() if len(df) > 0 else 0,
        )
        worksheet.set_column(col_num, col_num, min(max_len + 4, 30))

    # Zebra striping
    alt_fmt = workbook.add_format({"bg_color": "#F8FAFC"})
    for row_idx in range(len(df)):
        if row_idx % 2 == 0:
            for col_idx in range(len(df.columns)):
                val = df.iloc[row_idx, col_idx]
                worksheet.write(row_idx + 2, col_idx, val, alt_fmt)


_WRITERS = {
    ReportType.STAFF_SHIFTS: _write_staff_shifts,
    ReportType.PAYROLL: _write_payroll,
    ReportType.ATTENDANCE: _write_attendance,
}


def create_report(req: ReportRequest, output_path: str) -> None:
    writer_fn = _WRITERS.get(req.report_type)
    if not writer_fn:
        raise ValueError(f"Unknown report type: {req.report_type}")

    with pd.ExcelWriter(output_path, engine="xlsxwriter") as writer:
        writer_fn(req, writer)

        # Add metadata sheet
        workbook = writer.book
        meta_sheet = workbook.add_worksheet("Info")
        bold = workbook.add_format({"bold": True, "font_size": 11})
        meta_sheet.write(0, 0, "Report", bold)
        meta_sheet.write(0, 1, req.title)
        meta_sheet.write(1, 0, "Period", bold)
        meta_sheet.write(1, 1, req.period.label)
        meta_sheet.write(2, 0, "Generated", bold)
        meta_sheet.write(2, 1, datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"))
        meta_sheet.write(3, 0, "Company", bold)
        meta_sheet.write(3, 1, req.company_name)
        meta_sheet.set_column(0, 0, 12)
        meta_sheet.set_column(1, 1, 40)
