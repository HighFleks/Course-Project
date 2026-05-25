import json
import logging
import httpx
from fastapi import APIRouter, Depends, HTTPException, status

logger = logging.getLogger("meal_planner.barcode")
logger.setLevel(logging.INFO)
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models.barcode_cache import BarcodeCache
from app.models.ingredient import Ingredient
from app.schemas.barcode import BarcodeLookupRequest, BarcodeLookupResponse
from app.routers.auth import get_current_user
from app.models.user import User
from app.utils.ingredient_search import find_best_match

router = APIRouter(prefix="/api/barcode", tags=["barcode"])

OFF_MIRRORS = [
    "https://ru.openfoodfacts.org/api/v2/product/{}",
    "https://world.openfoodfacts.org/api/v2/product/{}",
]

OFF_TIMEOUT = httpx.Timeout(connect=3.0, read=5.0, write=3.0, pool=3.0)
OFF_HEADERS = {
    "User-Agent": "MealPlanner/1.0 (student@example.com)",
    "Accept": "application/json",
}

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

    # Проверяем кэш (игнорируем мусорные старые записи без имени).
    cache_result = await db.execute(
        select(BarcodeCache).where(BarcodeCache.barcode == barcode)
    )
    cached = cache_result.scalar_one_or_none()
    if cached and cached.product_name and cached.product_name != "Неизвестный продукт":
        ingredient = await _get_or_create_ingredient(db, cached.product_name, cached.unit)
        return BarcodeLookupResponse(
            barcode=barcode,
            product_name=ingredient.name,
            unit=ingredient.unit or cached.unit,
            ingredient_id=ingredient.id,
            cached=True,
        )

    # Запрос к OpenFoodFacts: пробуем зеркала по очереди
    transport = httpx.AsyncHTTPTransport(retries=0, local_address="0.0.0.0")
    data = None
    last_error: str | None = None
    async with httpx.AsyncClient(timeout=OFF_TIMEOUT, transport=transport) as client:
        for mirror_url in OFF_MIRRORS:
            url = mirror_url.format(barcode)
            try:
                logger.warning("OFF lookup url=%s", url)
                response = await client.get(url, headers=OFF_HEADERS)
                logger.warning(
                    "OFF response url=%s status=%d size=%d",
                    url, response.status_code, len(response.content)
                )

                if response.status_code == 404:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"Продукт со штрих-кодом {barcode} не найден в OpenFoodFacts"
                    )
                if response.status_code >= 400:
                    last_error = f"HTTP {response.status_code}"
                    continue  # пробуем следующее зеркало
                data = response.json()
                break
            except httpx.TimeoutException:
                last_error = "timeout"
                logger.warning("OFF timeout url=%s", url)
                continue  # следующее зеркало
            except httpx.RequestError as e:
                last_error = str(e)
                logger.warning("OFF network error url=%s err=%s", url, e)
                continue

    if data is None:
        raise HTTPException(
            status_code=504,
            detail=(
                f"OpenFoodFacts не отвечает ({last_error}). "
                "Попробуйте ещё раз или введите продукт вручную."
            )
        )

    # Проверяем статус ответа API (1 = продукт найден)
    if data.get("status") != 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with barcode {barcode} not found in Open Food Facts"
        )

    # Извлекаем название продукта (приоритет — русское название).
    product = data.get("product", {})
    product_name = (
        product.get("product_name_ru")
        or product.get("generic_name_ru")
        or product.get("product_name")
        or product.get("generic_name")
    )
    if not product_name or not product_name.strip():
        # OFF знает штрих-код, но названия в базе нет.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"OpenFoodFacts знает штрих-код {barcode}, но не имеет названия. Введите вручную."
        )
    product_name = product_name.strip()

    # Определяем единицу измерения
    unit = guess_unit(product_name)

    # Сохраняем в кэш
    cache_entry = BarcodeCache(
        barcode=barcode,
        product_name=product_name,
        unit=unit,
        raw_data=json.dumps(data, ensure_ascii=False) if product else None
    )
    db.add(cache_entry)
    await db.commit()

    # Найдём или создадим ингредиент
    ingredient = await _get_or_create_ingredient(db, product_name, unit)

    return BarcodeLookupResponse(
        barcode=barcode,
        product_name=ingredient.name,
        unit=ingredient.unit or unit,
        ingredient_id=ingredient.id,
        cached=False,
    )


async def _get_or_create_ingredient(db: AsyncSession, name: str, unit: str) -> Ingredient:
    best = await find_best_match(db, name)
    if best:
        if not best.unit and unit:
            best.unit = unit
            await db.commit()
        return best

    new_ingredient = Ingredient(name=name, unit=unit)
    db.add(new_ingredient)
    await db.commit()
    await db.refresh(new_ingredient)
    return new_ingredient