from fastapi import APIRouter, UploadFile, File, Depends
from sqlalchemy.orm import Session
import cv2
import numpy as np
from ..database import SessionLocal
from ..models import Session as SessionModel
from .admin import manager

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/proctor/upload-frame")
async def upload_frame(
    session_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    contents = await file.read()
    np_arr = np.frombuffer(contents, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    cheating = False
    message = "Clear"

    # 🔥 TEMP: Replace with your AI service
    if np.random.rand() > 0.7:
        cheating = True
        message = "Phone detected"

    session = db.query(SessionModel).filter(
        SessionModel.session_id == session_id
    ).first()

    if session:
        session.cheating = cheating
        session.message = message
        db.commit()

    # ✅ BROADCAST TO ADMIN LIVE
    await manager.broadcast({
        "session_id": session_id,
        "cheating": cheating,
        "message": message
    })

    return {"cheating": cheating, "message": message}