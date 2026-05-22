from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..models import User
from ..schemas import LoginRequest, TokenResponse, UserOut
from ..security import create_access_token, get_current_user, get_db, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def _role_matches(stored_role: str, requested_role: str) -> bool:
    aliases = {
        "student": {"student", "candidate"},
        "candidate": {"student", "candidate"},
        "proctor": {"proctor", "admin"},
        "admin": {"admin"},
        "teacher": {"teacher"},
    }
    return stored_role in aliases.get(requested_role, {requested_role})


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    identifier = payload.username.strip().lower()
    requested_role = payload.role.strip().lower()
    user = (
        db.query(User)
        .filter((User.username == identifier) | (User.email == identifier))
        .first()
    )

    if user is None or not _role_matches(user.role, requested_role) or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username, password, or role",
        )

    expires = timedelta(days=14) if payload.remember_me else timedelta(hours=8)
    token = create_access_token(user.username, user.role, expires)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user
