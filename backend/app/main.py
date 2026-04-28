from fastapi import FastAPI
from .database import engine
from .models import Base
from .routers import session, proctor, admin

app = FastAPI()

Base.metadata.create_all(bind=engine)

app.include_router(session.router)
app.include_router(proctor.router)
app.include_router(admin.router)

@app.get("/")
def root():
    return {"message": "ProctorAI running"}