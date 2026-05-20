from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.sql import func

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    role = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Session(Base):
    __tablename__ = "sessions"

    session_id = Column(String, primary_key=True, index=True)
    student_id = Column(String, index=True)
    student_name = Column(String, default="Candidate")
    subject = Column(String, default="GENERAL", index=True)
    exam_title = Column(String, default="Secure Exam")
    side_camera_url = Column(String, default="")
    side_camera_status = Column(String, default="UNKNOWN")
    is_active = Column(Boolean, default=True)
    is_submitted = Column(Boolean, default=False)
    is_terminated = Column(Boolean, default=False)
    is_cheating = Column(Boolean, default=False)
    status = Column(String, default="STARTING")
    risk_level = Column(String, default="LOW")
    cheat_type = Column(String, default="")
    cheat_message = Column(String, default="AI monitoring active")
    cheat_count = Column(Integer, default=0)
    warning_count = Column(Integer, default=0)
    tab_switch_count = Column(Integer, default=0)
    disconnect_count = Column(Integer, default=0)
    confidence = Column(Float, default=0.0)
    cheat_score = Column(Float, default=0.0)
    approval_status = Column(String, default="NOT_REQUIRED")
    approval_note = Column(Text, default="")
    answers_json = Column(Text, default="{}")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    submitted_at = Column(DateTime(timezone=True), nullable=True)


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String, ForeignKey("sessions.session_id"), index=True)
    event_type = Column(String, index=True)
    severity = Column(String, default="INFO")
    message = Column(String)
    confidence = Column(Float, default=0.0)
    score_delta = Column(Float, default=0.0)
    metadata_json = Column(Text, default="{}")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
