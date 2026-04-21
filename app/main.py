from fastapi import FastAPI
from app.database import engine, Base
from app.models import user, ingredient
from app.routers import auth, ingredients, recipes, inventory, shopping

app = FastAPI(
    title="Meal Planner API",
    version="0.1.0",
    swagger_ui_parameters={"persistAuthorization": True}
)

app.include_router(auth.router)
app.include_router(ingredients.router)
app.include_router(recipes.router)
app.include_router(inventory.router)
app.include_router(shopping.router)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/")
async def root():
    return {"message": "Meal Planner API is running!"}

# source venv/bin/activate
# docker ps
# docker compose up -d
# uvicorn app.main:app --reload --port 8000