from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models.ingredient import Ingredient
from app.models.user import User
from app.schemas.ingredient import IngredientCreate, IngredientOut
from app.routers.auth import get_current_user
from app.utils.ingredient_search import search_ingredients as _token_search

router = APIRouter(prefix="/api/ingredients", tags=["ingredients"])

@router.get("/", response_model=list[IngredientOut])
async def get_ingredients(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Ingredient).order_by(Ingredient.name))
    return result.scalars().all()


@router.get("/search", response_model=list[IngredientOut])
async def search_ingredients(
    q: str = "",
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return await _token_search(db, q, limit=limit)


@router.post("/", response_model=IngredientOut, status_code=status.HTTP_201_CREATED)
async def create_ingredient(
    ingredient_data: IngredientCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем, нет ли уже такого ингредиента
    existing = await db.execute(select(Ingredient).where(Ingredient.name == ingredient_data.name))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Ingredient already exists")
    new_ingredient = Ingredient(**ingredient_data.model_dump())
    db.add(new_ingredient)
    await db.commit()
    await db.refresh(new_ingredient)
    return new_ingredient