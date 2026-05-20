from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)
    role: str
    remember_me: bool = False


class UserOut(BaseModel):
    id: int
    username: str
    email: EmailStr
    full_name: str
    role: str

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class SessionStartRequest(BaseModel):
    session_id: str
    student_id: str
    student_name: str = "Candidate"
    exam_title: str = "Secure Exam"
    subject: str = "GENERAL"
    side_camera_url: str


class DetectionResponse(BaseModel):
    session_id: str
    cheating: bool
    message: str
    cheat_type: str = ""
    confidence: float = 0.0
    cheat_score: float = 0.0
    risk_level: str = "LOW"
    status: str = "CLEAR"
    warning_count: int = 0
    candidate_status: str = "CLEAR"
    side_camera_status: str = "UNKNOWN"
    events: List[Dict[str, Any]] = Field(default_factory=list)


class ProctorUpdateRequest(BaseModel):
    session_id: str
    cheating: bool
    cheat_type: str = ""
    message: str = "Clear"
    cheat_score_delta: float = 0.0


class ProctorSimpleResponse(BaseModel):
    cheating: bool
    message: str


class ClientEventRequest(BaseModel):
    event_type: str
    message: str
    severity: str = "INFO"
    score_delta: float = 0.0
    metadata: Dict[str, Any] = Field(default_factory=dict)


class SubmitExamRequest(BaseModel):
    answers: Dict[str, str]
    reason: str = "submitted_by_candidate"


class SessionOut(BaseModel):
    session_id: str
    student_id: str
    student_name: str
    subject: str
    exam_title: str
    side_camera_url: str
    side_camera_status: str
    is_active: bool
    is_submitted: bool
    is_terminated: bool
    is_cheating: bool
    status: str
    risk_level: str
    cheat_type: str
    cheat_message: str
    cheat_count: int
    warning_count: int
    tab_switch_count: int
    disconnect_count: int
    confidence: float
    cheat_score: float
    approval_status: str
    approval_note: str
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    submitted_at: Optional[datetime]

    class Config:
        from_attributes = True


class EventOut(BaseModel):
    id: int
    session_id: str
    event_type: str
    severity: str
    message: str
    confidence: float
    score_delta: float
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: Optional[datetime]


class DashboardStats(BaseModel):
    total_active: int
    total_cheating: int
    total_high_risk: int
    total_submitted: int
    total_events: int
