import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.barcode_cache import BarcodeCache
from app.models.ingredient import Ingredient
from app.schemas.barcode import BarcodeLookupRequest, BarcodeLookupResponse
from app.routers.auth import get_current_user
from app.models.user import User

router = APIRouter(prefix="/api/barcode", tags=["barcode"])

OPEN_FOOD_FACTS_URL = "https://world.openfoodfacts.org/api/v2/product/{}"

# Вспомогательная функция для определения единицы измерения
def guess_unit(product_name: str) -> str:
    name_lower = product_name.lower()
    if any(word in name_lower for word in ["молоко", "сок", "напиток", "вода"]):
        return "мл"
    elif any(word in name_lower for word in ["мука", "сахар", "крупа", "рис", "макароны"]):
        return "г"
    else:
        return "шт"

@router.post("/lookup", response_model=BarcodeLookupResponse)
async def lookup_barcode(
    request: BarcodeLookupRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    barcode = request.barcode.strip()
    if not barcode:
        raise HTTPException(status_code=400, detail="Barcode cannot be empty")

    # 1. Проверяем кэш
    cache_result = await db.execute(
        select(BarcodeCache).where(BarcodeCache.barcode == barcode)
    )
    cached = cache_result.scalar_one_or_none()
    if cached:
        ingredient_id = await _get_or_create_ingredient(db, cached.product_name, cached.unit)
        return BarcodeLookupResponse(
            barcode=barcode,
            product_name=cached.product_name,
            unit=cached.unit,
            ingredient_id=ingredient_id,
            cached=True
        )

    # 2. Запрос к Open Food Facts с User-Agent
    headers = {"User-Agent": "MealPlanner/1.0 (student@example.com)"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                OPEN_FOOD_FACTS_URL.format(barcode),
                headers=headers
            )
            response.raise_for_status()
            data = response.json()
        except httpx.TimeoutException:
            raise HTTPException(status_code=504, detail="Open Food Facts API timeout")
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=502,
                detail=f"Open Food Facts API error: {e.response.status_code}"
            )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=503,
                detail=f"Failed to connect to Open Food Facts: {str(e)}"
            )

    # 3. Проверяем статус ответа API (1 = продукт найден)
    if data.get("status") != 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with barcode {barcode} not found in Open Food Facts"
        )

    # 4. Извлекаем название продукта
    product = data.get("product", {})
    product_name = product.get("product_name") or product.get("generic_name")
    if not product_name:
        product_name = product.get("product_name_ru") or product.get("generic_name_ru")
    if not product_name:
        product_name = "Неизвестный продукт"

    # 5. Определяем единицу измерения
    unit = guess_unit(product_name)

    # 6. Сохраняем в кэш
    cache_entry = BarcodeCache(
        barcode=barcode,
        product_name=product_name,
        unit=unit,
        raw_data=str(data) if product else None
    )
    db.add(cache_entry)
    await db.commit()

    # 7. Найдём или создадим ингредиент
    ingredient_id = await _get_or_create_ingredient(db, product_name, unit)

    return BarcodeLookupResponse(
        barcode=barcode,
        product_name=product_name,
        unit=unit,
        ingredient_id=ingredient_id,
        cached=False
    )

async def _get_or_create_ingredient(db: AsyncSession, name: str, unit: str) -> int:
    """Находит ингредиент по имени или создаёт новый. Возвращает его ID."""
    # Пытаемся найти точное совпадение
    result = await db.execute(select(Ingredient).where(Ingredient.name == name))
    ingredient = result.scalar_one_or_none()
    
    if ingredient:
        # Обновим единицу измерения, если она была пустая
        if not ingredient.unit and unit:
            ingredient.unit = unit
            await db.commit()
        return ingredient.id
    
    # Если точного совпадения нет, создаём новый ингредиент
    new_ingredient = Ingredient(name=name, unit=unit)
    db.add(new_ingredient)
    await db.commit()
    await db.refresh(new_ingredient)
    return new_ingredient.id