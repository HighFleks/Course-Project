from fastapi import FastAPI
from app.database import engine, Base
from app.models import user
from app.routers import auth

app = FastAPI(
    title="Meal Planner API",
    version="0.1.0",
    swagger_ui_parameters={"persistAuthorization": True}  # чтобы токен не сбрасывался при обновлении страницы
)

app.include_router(auth.router)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/")
async def root():
    return {"message": "Meal Planner API is running!"}