import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

load_dotenv()

configured_database_url = os.getenv("DATABASE_URL", "").strip()
if configured_database_url.startswith("postgres://"):
    configured_database_url = configured_database_url.replace("postgres://", "postgresql://", 1)

use_external_database = (
    os.getenv("APP_ENV") == "production"
    or os.getenv("RENDER") is not None
    or os.getenv("PROCTORAI_USE_DATABASE_URL") == "true"
)
DATABASE_URL = configured_database_url if configured_database_url and use_external_database else "sqlite:///./proctorai.db"

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
