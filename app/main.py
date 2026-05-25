from fastapi import FastAPI
from app.database import engine, Base
from app.routers import (
    auth,
    ingredients,
    recipes,
    inventory,
    shopping,
    favorites,
    barcode
)
from contextlib import asynccontextmanager


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("✅ Инициализация БД...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    try:
        yield
    finally:
        await engine.dispose()
        print("❌ Соединения закрыты")


app = FastAPI(
    title="Meal Planner API",
    version="0.1.0",
    swagger_ui_parameters={"persistAuthorization": True},
    lifespan=lifespan
)

app.include_router(auth.router)
app.include_router(ingredients.router)
app.include_router(recipes.router)
app.include_router(inventory.router)
app.include_router(shopping.router)
app.include_router(favorites.router)
app.include_router(barcode.router)


@app.get("/")
async def root():
    return {"message": "Meal Planner API is running!", "status": "ok"}
# # Запуск (в terminal)
# if __name__ == "__main__":
#     import uvicorn
#     uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)

# source venv/bin/activate
# docker ps
# docker compose up -d
# uvicorn app.main:app --reload --port 8000
# http://127.0.0.1:8000/docs#/
# uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload - для тестов на телефоне

# {
#   "email": "user@example.com",
#   "password": "string"
# }