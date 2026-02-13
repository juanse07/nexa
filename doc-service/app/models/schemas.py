from __future__ import annotations

from enum import Enum
from typing import Any

from pydantic import BaseModel


class ReportFormat(str, Enum):
    PDF = "pdf"
    DOCX = "docx"
    XLSX = "xlsx"


class TemplateDesign(str, Enum):
    PLAIN = "plain"
    CLASSIC = "classic"
    EXECUTIVE = "executive"


class ReportType(str, Enum):
    STAFF_SHIFTS = "staff-shifts"
    PAYROLL = "payroll"
    ATTENDANCE = "attendance"
    AI_ANALYSIS = "ai-analysis"
    WORKING_HOURS = "working-hours"


class Period(BaseModel):
    start: str
    end: str
    label: str


class StaffShiftRecord(BaseModel):
    date: str
    eventName: str
    clientName: str = ""
    venueName: str = ""
    role: str = "Staff"
    clockIn: str = ""
    clockOut: str = ""
    hoursWorked: float = 0
    hourlyRate: float = 0
    earnings: float = 0


class PayrollRecord(BaseModel):
    name: str
    email: str = ""
    shifts: int = 0
    hours: float = 0
    averageRate: float = 0
    totalPay: float = 0


class AttendanceRecord(BaseModel):
    date: str
    eventName: str = "Event"
    staffName: str = "Unknown"
    role: str = "Staff"
    scheduledStart: str = ""
    scheduledEnd: str = ""
    clockIn: str = ""
    clockOut: str = ""
    hoursWorked: float = 0
    status: str = "unknown"


class BrandConfig(BaseModel):
    primary_color: str = "#1e293b"
    secondary_color: str = "#334155"
    accent_color: str = "#3b82f6"
    neutral_color: str = "#f8fafc"
    logo_header_url: str | None = None
    logo_watermark_url: str | None = None


class ReportRequest(BaseModel):
    report_type: ReportType
    report_format: ReportFormat
    title: str
    period: Period
    records: list[dict[str, Any]]
    summary: dict[str, Any] = {}
    company_name: str = "Nexa"
    brand_config: BrandConfig | None = None
    template_design: TemplateDesign = TemplateDesign.CLASSIC


class ReportResponse(BaseModel):
    filename: str
    content_type: str
