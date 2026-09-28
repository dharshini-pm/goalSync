import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    SQLITE_DB_PATH: str = os.path.abspath(
        os.path.join(os.path.dirname(os.path.dirname(__file__)), "goalsync.db")
    )
    DATABASE_NAME: str = "goalsync.db"
    JWT_SECRET: str = "super-secret-key-change-this-in-production-32-bytes"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    GOALSYNC_ALLOW_DEV_USER_MAPPING: bool = False
    MONGODB_URI: str = ""

    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
