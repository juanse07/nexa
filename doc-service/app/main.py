import os
import uuid

from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import FileResponse

from app.config import settings
from app.models.schemas import ReportFormat, ReportRequest
from app.services import excel_service, pdf_service, word_service

app = FastAPI(
    title="Nexa Document Generation Service",
    version="1.0.0",
    description="Microservice for generating PDF, Word, and Excel reports",
)

os.makedirs(settings.OUTPUT_DIR, exist_ok=True)


@app.get("/healthz")
async def health():
    return {"status": "ok", "service": "doc-service"}


@app.post("/generate-report")
async def generate_report(
    request: ReportRequest,
    x_service_secret: str | None = Header(default=None),
):
    if settings.SERVICE_SECRET and x_service_secret != settings.SERVICE_SECRET:
        raise HTTPException(status_code=401, detail="Invalid service secret")

    file_id = uuid.uuid4().hex[:12]
    ext_map = {
        ReportFormat.PDF: ".pdf",
        ReportFormat.DOCX: ".docx",
        ReportFormat.XLSX: ".xlsx",
    }
    ext = ext_map[request.report_format]
    filename = f"{request.report_type.value}_{file_id}{ext}"
    filepath = os.path.join(settings.OUTPUT_DIR, filename)

    if request.report_format == ReportFormat.PDF:
        pdf_service.create_report(request, filepath)
    elif request.report_format == ReportFormat.DOCX:
        word_service.create_report(request, filepath)
    elif request.report_format == ReportFormat.XLSX:
        excel_service.create_report(request, filepath)
    else:
        raise HTTPException(status_code=400, detail="Invalid report format")

    content_type_map = {
        ReportFormat.PDF: "application/pdf",
        ReportFormat.DOCX: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ReportFormat.XLSX: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }

    return FileResponse(
        path=filepath,
        filename=filename,
        media_type=content_type_map[request.report_format],
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        log_level=settings.LOG_LEVEL,
    )
