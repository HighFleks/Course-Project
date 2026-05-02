from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.database import get_db
from app.models.user import User
from app.models.recipe import Recipe
from app.models.favorite import FavoriteRecipe
from app.schemas.favorite import FavoriteCreate, FavoriteOut
from app.routers.auth import get_current_user

router = APIRouter(prefix="/api/favorites", tags=["favorites"])


@router.get("/", response_model=list[int])  # возвращаем список ID рецептов в избранном
async def get_favorites(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(FavoriteRecipe.recipe_id)
        .where(FavoriteRecipe.user_id == current_user.id)
    )
    return result.scalars().all()


@router.post("/", response_model=FavoriteOut, status_code=status.HTTP_201_CREATED)
async def add_to_favorites(
    fav_data: FavoriteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем существование рецепта
    recipe = await db.get(Recipe, fav_data.recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    # Проверяем, не добавлен ли уже
    existing = await db.execute(
        select(FavoriteRecipe)
        .where(
            FavoriteRecipe.user_id == current_user.id,
            FavoriteRecipe.recipe_id == fav_data.recipe_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Recipe already in favorites")
    # Создаём запись
    new_fav = FavoriteRecipe(user_id=current_user.id, recipe_id=fav_data.recipe_id)
    db.add(new_fav)
    await db.commit()
    await db.refresh(new_fav)
    return new_fav


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_from_favorites(
    recipe_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        delete(FavoriteRecipe)
        .where(
            FavoriteRecipe.user_id == current_user.id,
            FavoriteRecipe.recipe_id == recipe_id
        )
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Favorite not found")
    await db.commit()
    return