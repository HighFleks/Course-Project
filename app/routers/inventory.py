from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.ingredient import Ingredient
from app.models.inventory import UserInventory
from app.schemas.inventory import InventoryItemCreate, InventoryItemUpdate, InventoryItemOut
from app.routers.auth import get_current_user

router = APIRouter(prefix="/api/inventory", tags=["inventory"])


@router.get("/", response_model=list[InventoryItemOut])
async def get_inventory(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(UserInventory)
        .where(UserInventory.user_id == current_user.id)
        .options(selectinload(UserInventory.ingredient))
        .order_by(UserInventory.id)
    )
    items = result.scalars().all()
    return items


@router.post("/", response_model=InventoryItemOut, status_code=status.HTTP_201_CREATED)
async def add_to_inventory(
    item_data: InventoryItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Проверяем существование ингредиента
    ingredient = await db.get(Ingredient, item_data.ingredient_id)
    if not ingredient:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    # Проверяем, есть ли уже такой продукт у пользователя
    existing = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.user_id == current_user.id,
            UserInventory.ingredient_id == item_data.ingredient_id
        )
    )
    existing_item = existing.scalar_one_or_none()

    if existing_item:
        # Увеличиваем количество
        existing_item.quantity += item_data.quantity
        await db.commit()
        await db.refresh(existing_item)
        # Подгружаем связь с ингредиентом для ответа
        result = await db.execute(
            select(UserInventory)
            .where(UserInventory.id == existing_item.id)
            .options(selectinload(UserInventory.ingredient))
        )
        return result.scalar_one()
    else:
        # Создаём новую запись
        new_item = UserInventory(
            user_id=current_user.id,
            ingredient_id=item_data.ingredient_id,
            quantity=item_data.quantity
        )
        db.add(new_item)
        await db.commit()
        await db.refresh(new_item)
        # Подгружаем ингредиент
        result = await db.execute(
            select(UserInventory)
            .where(UserInventory.id == new_item.id)
            .options(selectinload(UserInventory.ingredient))
        )
        return result.scalar_one()


@router.put("/{ingredient_id}", response_model=InventoryItemOut)
async def update_inventory_item(
    ingredient_id: int,
    item_data: InventoryItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Ищем запись инвентаря для данного ингредиента
    result = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.user_id == current_user.id,
            UserInventory.ingredient_id == ingredient_id
        )
        .options(selectinload(UserInventory.ingredient))
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    item.quantity = item_data.quantity
    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/{ingredient_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_inventory_item(
    ingredient_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.user_id == current_user.id,
            UserInventory.ingredient_id == ingredient_id
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    await db.delete(item)
    await db.commit()
    return