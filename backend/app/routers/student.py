from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..models import Exam, QuestionImage, StudentProfile, Subject, User
from ..schemas import StudentProfileIn, StudentProfileOut
from ..security import get_current_user, get_db, require_role

router = APIRouter(prefix="/student", tags=["student"])


def _profile_complete(profile: StudentProfile | None) -> bool:
    if profile is None:
        return False
    return all([
        profile.full_name.strip(),
        profile.prn.strip(),
        profile.branch.strip(),
        profile.division.strip(),
        profile.semester.strip(),
        profile.year.strip(),
    ])


def _profile_payload(profile: StudentProfile | None, user: User) -> dict:
    if profile is None:
        return {
            "complete": False,
            "user_id": user.id,
            "full_name": user.full_name,
            "prn": "",
            "branch": "",
            "division": "",
            "semester": "",
            "year": "",
        }
    data = StudentProfileOut.model_validate(profile).model_dump(mode="json")
    data["complete"] = _profile_complete(profile)
    return data


@router.get("/profile")
def get_profile(
    db: Session = Depends(get_db),
    user: User = Depends(require_role("candidate", "student")),
):
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    return _profile_payload(profile, user)


@router.put("/profile")
def update_profile(
    payload: StudentProfileIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_role("candidate", "student")),
):
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    if profile is None:
        profile = StudentProfile(
            user_id=user.id,
            full_name=payload.full_name.strip(),
            prn=payload.prn.strip().upper(),
            branch=payload.branch.strip().upper(),
            division=payload.division.strip().upper(),
            semester=payload.semester.strip(),
            year=payload.year.strip(),
        )
        db.add(profile)
    else:
        profile.full_name = payload.full_name.strip()
        profile.prn = payload.prn.strip().upper()
        profile.branch = payload.branch.strip().upper()
        profile.division = payload.division.strip().upper()
        profile.semester = payload.semester.strip()
        profile.year = payload.year.strip()
    user.full_name = payload.full_name.strip()
    db.commit()
    db.refresh(profile)
    return _profile_payload(profile, user)


@router.get("/exams")
def available_exams(
    db: Session = Depends(get_db),
    user: User = Depends(require_role("candidate", "student")),
):
    profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    if not _profile_complete(profile):
        raise HTTPException(status_code=409, detail="Complete student profile before joining exams")

    now = datetime.now(timezone.utc)
    rows = (
        db.query(Exam, Subject)
        .join(Subject, Exam.subject_id == Subject.id)
        .filter(Exam.is_published == True)
        .order_by(Exam.created_at.desc())
        .all()
    )
    exams = []
    for exam, subject in rows:
        if subject.branch and subject.branch != profile.branch:
            continue
        if subject.division and subject.division != profile.division:
            continue
        if subject.semester and subject.semester != profile.semester:
            continue
        if exam.end_time and exam.end_time < now:
            continue
        question_count = db.query(QuestionImage).filter(QuestionImage.exam_id == exam.id).count()
        exams.append({
            "id": exam.id,
            "title": exam.title,
            "subject_id": subject.id,
            "subject": subject.subject_code,
            "subject_name": subject.subject_name,
            "branch": subject.branch,
            "division": subject.division,
            "semester": subject.semester,
            "duration_minutes": exam.duration_minutes,
            "total_marks": exam.total_marks,
            "instructions": exam.instructions,
            "start_time": exam.start_time,
            "end_time": exam.end_time,
            "question_count": question_count,
        })
    return exams
