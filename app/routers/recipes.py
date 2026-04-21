from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.recipe import Recipe, RecipeIngredient
from app.models.ingredient import Ingredient
from app.schemas.recipe import RecipeCreate, RecipeUpdate, RecipeOut
from app.routers.auth import get_current_user
from app.models.user import User
from collections import defaultdict
from app.models.inventory import UserInventory

async def is_recipe_available(
    recipe: Recipe,
    user_id: int,
    db: AsyncSession
) -> tuple[bool, dict[int, float]]:
    """
    Проверяет, можно ли приготовить рецепт из инвентаря пользователя.
    Возвращает (True, {}) если хватает всех ингредиентов,
    иначе (False, {ingredient_id: недостающее_количество}).
    """
    # Загружаем инвентарь пользователя
    inv_result = await db.execute(
        select(UserInventory)
        .where(UserInventory.user_id == user_id)
    )
    inventory = {item.ingredient_id: item.quantity for item in inv_result.scalars().all()}

    missing = {}
    for rec_ing in recipe.ingredients:
        required = rec_ing.quantity
        available = inventory.get(rec_ing.ingredient_id, 0.0)
        if available < required:
            missing[rec_ing.ingredient_id] = required - available

    return len(missing) == 0, missing

router = APIRouter(prefix="/api/recipes", tags=["recipes"])

@router.get("/", response_model=list[RecipeOut])
async def get_recipes(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)  # опционально: фильтр по своим
):
    # Показываем все публичные рецепты + рецепты текущего пользователя
    query = select(Recipe).where(
        (Recipe.is_public == True) | (Recipe.created_by_user_id == current_user.id)
    ).options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))
    result = await db.execute(query)
    return result.scalars().unique().all()


@router.post("/", response_model=RecipeOut, status_code=status.HTTP_201_CREATED)
async def create_recipe(
    recipe_data: RecipeCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Создаём рецепт
    new_recipe = Recipe(
        name=recipe_data.name,
        description=recipe_data.description,
        instructions=recipe_data.instructions,
        image_url=recipe_data.image_url,
        category=recipe_data.category,
        is_public=recipe_data.is_public,
        created_by_user_id=current_user.id
    )
    db.add(new_recipe)
    await db.flush()  # чтобы получить id рецепта

    # Добавляем ингредиенты
    for ing in recipe_data.ingredients:
        # Проверим, существует ли ингредиент
        ing_obj = await db.get(Ingredient, ing.ingredient_id)
        if not ing_obj:
            raise HTTPException(status_code=400, detail=f"Ingredient {ing.ingredient_id} not found")
        rec_ing = RecipeIngredient(
            recipe_id=new_recipe.id,
            ingredient_id=ing.ingredient_id,
            quantity=ing.quantity
        )
        db.add(rec_ing)

    await db.commit()
    # Перезагружаем объект с ингредиентами
    await db.refresh(new_recipe)
    # Явно подгружаем связи
    result = await db.execute(
        select(Recipe)
        .where(Recipe.id == new_recipe.id)
        .options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))
    )
    return result.scalar_one()


@router.get("/{recipe_id}", response_model=RecipeOut)
async def get_recipe(
    recipe_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(Recipe)
        .where(Recipe.id == recipe_id)
        .options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    # Проверка доступа: публичный или свой
    if not recipe.is_public and recipe.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    return recipe


@router.put("/{recipe_id}", response_model=RecipeOut)
async def update_recipe(
    recipe_id: int,
    recipe_data: RecipeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(Recipe)
        .where(Recipe.id == recipe_id)
        .options(selectinload(Recipe.ingredients))
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if recipe.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can edit")

    # Обновляем поля
    update_data = recipe_data.model_dump(exclude_unset=True, exclude={"ingredients"})
    for field, value in update_data.items():
        setattr(recipe, field, value)

    # Если передан список ингредиентов, заменяем
    if recipe_data.ingredients is not None:
        # Удаляем старые
        for old_ing in recipe.ingredients:
            await db.delete(old_ing)
        # Добавляем новые
        for ing in recipe_data.ingredients:
            ing_obj = await db.get(Ingredient, ing.ingredient_id)
            if not ing_obj:
                raise HTTPException(status_code=400, detail=f"Ingredient {ing.ingredient_id} not found")
            new_ing = RecipeIngredient(
                recipe_id=recipe.id,
                ingredient_id=ing.ingredient_id,
                quantity=ing.quantity
            )
            db.add(new_ing)

    await db.commit()
    await db.refresh(recipe)
    # Подгружаем ингредиенты с их данными
    result = await db.execute(
        select(Recipe)
        .where(Recipe.id == recipe.id)
        .options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))
    )
    return result.scalar_one()


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recipe(
    recipe_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Recipe).where(Recipe.id == recipe_id))
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if recipe.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can delete")

    await db.delete(recipe)
    await db.commit()
    return

@router.get("/available", response_model=list[RecipeOut])
async def get_available_recipes(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Возвращает список рецептов, которые можно приготовить полностью из инвентаря пользователя.
    """
    # Получаем все рецепты, доступные пользователю (публичные + свои)
    query = select(Recipe).where(
        (Recipe.is_public == True) | (Recipe.created_by_user_id == current_user.id)
    ).options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))

    result = await db.execute(query)
    all_recipes = result.scalars().unique().all()

    available_recipes = []
    for recipe in all_recipes:
        is_avail, _ = await is_recipe_available(recipe, current_user.id, db)
        if is_avail:
            available_recipes.append(recipe)

    return available_recipes


@router.get("/random-suggestion", response_model=RecipeOut)
async def get_random_recipe_suggestion(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Возвращает случайный рецепт из тех, что можно приготовить из инвентаря.
    Если доступных рецептов нет, возвращает 404.
    """
    import random

    # Получаем все доступные рецепты (логика та же)
    query = select(Recipe).where(
        (Recipe.is_public == True) | (Recipe.created_by_user_id == current_user.id)
    ).options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient))

    result = await db.execute(query)
    all_recipes = result.scalars().unique().all()

    available = []
    for recipe in all_recipes:
        is_avail, _ = await is_recipe_available(recipe, current_user.id, db)
        if is_avail:
            available.append(recipe)

    if not available:
        raise HTTPException(status_code=404, detail="No available recipes found in your inventory")

    return random.choice(available)