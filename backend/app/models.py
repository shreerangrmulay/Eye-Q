from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.sql import func
from .database import Base

class Session(Base):
    __tablename__ = "sessions"

    session_id = Column(String, primary_key=True, index=True)
    student_id = Column(String)
    cheating = Column(Boolean, default=False)
    message = Column(String, default="Starting")
    created_at = Column(DateTime(timezone=True), server_default=func.now())