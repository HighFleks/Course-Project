from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from collections import defaultdict

from app.database import get_db
from app.models.user import User
from app.models.ingredient import Ingredient
from app.models.recipe import Recipe, RecipeIngredient
from app.models.inventory import UserInventory
from app.models.shopping_list import ShoppingListItem
from app.schemas.shopping_list import (
    ShoppingListItemCreate,
    ShoppingListItemUpdate,
    ShoppingListItemOut,
    GenerateShoppingListRequest,
)
from app.routers.auth import get_current_user

router = APIRouter(prefix="/api/shopping-list", tags=["shopping list"])


@router.get("/", response_model=list[ShoppingListItemOut])
async def get_shopping_list(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(ShoppingListItem)
        .where(ShoppingListItem.user_id == current_user.id)
        .options(selectinload(ShoppingListItem.ingredient))
        .order_by(ShoppingListItem.id)
    )
    items = result.scalars().all()
    return items


@router.post("/generate", response_model=list[ShoppingListItemOut])
async def generate_shopping_list(
    request: GenerateShoppingListRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Генерирует список покупок на основе выбранных рецептов.
    Учитывает имеющиеся продукты в инвентаре.
    """
    # Получаем рецепты с ингредиентами
    recipe_ids = request.recipe_ids
    if not recipe_ids:
        raise HTTPException(status_code=400, detail="No recipe IDs provided")

    recipes_result = await db.execute(
        select(Recipe)
        .where(Recipe.id.in_(recipe_ids))
        .options(selectinload(Recipe.ingredients))
    )
    recipes = recipes_result.scalars().all()
    if len(recipes) != len(recipe_ids):
        raise HTTPException(status_code=404, detail="One or more recipes not found")

    # Суммируем потребность по всем рецептам
    required = defaultdict(float)
    for recipe in recipes:
        # Проверка доступа (пользователь может видеть только публичные или свои)
        if not recipe.is_public and recipe.created_by_user_id != current_user.id:
            raise HTTPException(status_code=403, detail=f"Access denied to recipe {recipe.id}")
        for ing in recipe.ingredients:
            required[ing.ingredient_id] += ing.quantity

    # Получаем инвентарь пользователя
    inv_result = await db.execute(
        select(UserInventory).where(UserInventory.user_id == current_user.id)
    )
    inventory = {item.ingredient_id: item.quantity for item in inv_result.scalars().all()}

    # Вычисляем недостающее (required - available)
    to_buy = {}
    for ing_id, req_qty in required.items():
        available = inventory.get(ing_id, 0.0)
        missing = req_qty - available
        if missing > 0:
            to_buy[ing_id] = missing

    # Очищаем старый список покупок пользователя (упрощённый подход — один активный список)
    await db.execute(
        select(ShoppingListItem).where(ShoppingListItem.user_id == current_user.id)
    )
    # Удаляем все старые записи
    old_items = (await db.execute(
        select(ShoppingListItem).where(ShoppingListItem.user_id == current_user.id)
    )).scalars().all()
    for item in old_items:
        await db.delete(item)

    # Создаём новые записи
    new_items = []
    for ing_id, qty in to_buy.items():
        item = ShoppingListItem(
            user_id=current_user.id,
            ingredient_id=ing_id,
            quantity=qty,
            is_purchased=False
        )
        db.add(item)
        new_items.append(item)

    await db.commit()

    # Загружаем созданные элементы с ингредиентами
    result = await db.execute(
        select(ShoppingListItem)
        .where(ShoppingListItem.user_id == current_user.id)
        .options(selectinload(ShoppingListItem.ingredient))
    )
    return result.scalars().all()


@router.put("/items/{ingredient_id}", response_model=ShoppingListItemOut)
async def update_shopping_list_item(
    ingredient_id: int,
    update_data: ShoppingListItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(ShoppingListItem)
        .where(
            ShoppingListItem.user_id == current_user.id,
            ShoppingListItem.ingredient_id == ingredient_id
        )
        .options(selectinload(ShoppingListItem.ingredient))
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found in shopping list")

    if update_data.quantity is not None:
        item.quantity = update_data.quantity
    if update_data.is_purchased is not None:
        item.is_purchased = update_data.is_purchased

    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/items/{ingredient_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_shopping_list_item(
    ingredient_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(ShoppingListItem)
        .where(
            ShoppingListItem.user_id == current_user.id,
            ShoppingListItem.ingredient_id == ingredient_id
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found in shopping list")

    await db.delete(item)
    await db.commit()
    return


@router.post("/checkout", response_model=list[ShoppingListItemOut])
async def checkout_shopping_list(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Отмечает все купленные товары и переносит их в инвентарь.
    Возвращает оставшиеся (некупленные) позиции списка.
    """
    # Получаем все элементы списка покупок пользователя
    items_result = await db.execute(
        select(ShoppingListItem)
        .where(ShoppingListItem.user_id == current_user.id)
        .options(selectinload(ShoppingListItem.ingredient))
    )
    items = items_result.scalars().all()

    purchased_items = [item for item in items if item.is_purchased]

    if not purchased_items:
        raise HTTPException(status_code=400, detail="No purchased items to checkout")

    # Переносим в инвентарь
    for purchased in purchased_items:
        # Ищем запись в инвентаре
        inv_result = await db.execute(
            select(UserInventory)
            .where(
                UserInventory.user_id == current_user.id,
                UserInventory.ingredient_id == purchased.ingredient_id
            )
        )
        inv_item = inv_result.scalar_one_or_none()
        if inv_item:
            inv_item.quantity += purchased.quantity
        else:
            new_inv = UserInventory(
                user_id=current_user.id,
                ingredient_id=purchased.ingredient_id,
                quantity=purchased.quantity
            )
            db.add(new_inv)

        # Удаляем купленный элемент из списка покупок
        await db.delete(purchased)

    await db.commit()

    # Возвращаем оставшиеся элементы
    remaining_result = await db.execute(
        select(ShoppingListItem)
        .where(ShoppingListItem.user_id == current_user.id)
        .options(selectinload(ShoppingListItem.ingredient))
    )
    return remaining_result.scalars().all()