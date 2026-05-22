from .models import Session as SessionModel
from .schemas import SessionOut, StudentMonitoringResponse


STAFF_ROLES = {"admin", "proctor"}
STUDENT_ROLES = {"candidate", "student"}


def is_staff_role(role: str) -> bool:
    return role in STAFF_ROLES


def is_student_role(role: str) -> bool:
    return role in STUDENT_ROLES


def admin_session_payload(session: SessionModel, message_type: str = "session") -> dict:
    payload = SessionOut.model_validate(session).model_dump(mode="json")
    payload["type"] = message_type
    payload["candidate_status"] = session.status
    payload["message"] = session.cheat_message
    return payload


def _candidate_safe_status(status: str) -> str:
    if status in {
        "REJOIN_PENDING",
        "REJOIN_DENIED",
        "SUBMITTED",
        "TERMINATED",
        "AUTO_SUBMIT_REQUIRED",
    }:
        return status
    return "MONITORING"


def student_session_payload(session: SessionModel, message_type: str = "monitoring") -> dict:
    safe_status = _candidate_safe_status(session.status)
    return StudentMonitoringResponse(
        type=message_type,
        session_id=session.session_id,
        student_id=session.student_id,
        student_name=session.student_name,
        subject=session.subject,
        exam_title=session.exam_title,
        side_camera_status=session.side_camera_status,
        is_active=session.is_active,
        is_submitted=session.is_submitted,
        is_terminated=session.is_terminated,
        status=safe_status,
        candidate_status=safe_status,
        approval_status=session.approval_status,
        approval_note=session.approval_note,
    ).model_dump(mode="json")


async def broadcast_monitoring_update(manager, session: SessionModel, message_type: str = "monitoring") -> None:
    await manager.broadcast_admin(admin_session_payload(session, message_type))
    await manager.broadcast_session(session.session_id, student_session_payload(session, message_type))
