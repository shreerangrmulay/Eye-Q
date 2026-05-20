from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from .database import engine
from .models import Base, Session as ExamSession, User
from .routers import admin, auth, proctor, session
from .security import get_db, hash_password

app = FastAPI(
    title="ProctorAI Unified API",
    version="3.1.0",
    description="Single backend for local AI proctoring, Render deployment, auth, sessions, and admin monitoring.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Base.metadata.create_all(bind=engine)


def ensure_schema():
    additions = {
        "subject": "VARCHAR DEFAULT 'GENERAL'",
        "side_camera_url": "VARCHAR DEFAULT ''",
        "side_camera_status": "VARCHAR DEFAULT 'UNKNOWN'",
        "approval_status": "VARCHAR DEFAULT 'NOT_REQUIRED'",
        "approval_note": "TEXT DEFAULT ''",
    }
    with engine.begin() as connection:
        existing = {column["name"] for column in inspect(connection).get_columns("sessions")}
        for column, definition in additions.items():
            if column not in existing:
                connection.execute(text(f"ALTER TABLE sessions ADD COLUMN {column} {definition}"))


ensure_schema()


def seed_users():
    defaults = [
        ("candidate", "candidate@exam.ai", "Candidate Demo", "candidate", "student123"),
        ("student", "student@exam.ai", "Student Demo", "candidate", "student123"),
        ("admin", "admin@proctor.ai", "Proctor Admin", "admin", "admin123"),
    ]
    db = Session(bind=engine)
    try:
        for username, email, full_name, role, password in defaults:
            exists = db.query(User).filter(User.username == username).first()
            if exists is None:
                db.add(User(
                    username=username,
                    email=email,
                    full_name=full_name,
                    role=role,
                    password_hash=hash_password(password),
                ))
        db.commit()
    finally:
        db.close()

seed_users()

app.include_router(auth.router)
app.include_router(session.router)
app.include_router(proctor.router)
app.include_router(admin.router)

@app.get("/")
def root(db: Session = Depends(get_db)):
    active_sessions = db.query(ExamSession).filter(ExamSession.is_active == True).count()
    return {
        "status": "ProctorAI Unified API running",
        "version": "3.1.0",
        "active_sessions": active_sessions,
    }


@app.get("/health")
def health(db: Session = Depends(get_db)):
    active_sessions = db.query(ExamSession).filter(ExamSession.is_active == True).count()
    return {"status": "ok", "active_sessions": active_sessions}
