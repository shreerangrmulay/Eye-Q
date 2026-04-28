from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import SessionLocal
from ..models import Session as SessionModel

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/session/start")
def start_session(session_id: str, student_id: str, db: Session = Depends(get_db)):
    session = SessionModel(
        session_id=session_id,
        student_id=student_id
    )
    db.add(session)
    db.commit()
    return {"status": "session started"}