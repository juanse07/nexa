import os


class Settings:
    HOST: str = os.getenv("DOC_SERVICE_HOST", "0.0.0.0")
    PORT: int = int(os.getenv("DOC_SERVICE_PORT", "5000"))
    OUTPUT_DIR: str = os.getenv("DOC_OUTPUT_DIR", "/tmp/doc-service")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "info")
    # Shared secret for service-to-service auth
    SERVICE_SECRET: str = os.getenv("DOC_SERVICE_SECRET", "")


settings = Settings()
