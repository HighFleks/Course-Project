import re
from typing import Optional
from sqlalchemy import select, case, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.ingredient import Ingredient


# Минимальная длина токена. Короче - отбрасываем как шум ("г", "мл", "1l")
_MIN_TOKEN_LEN = 3
# Символы-разделители - пробелы, знаки препинания, кавычки, проценты
_SPLIT_RE = re.compile(r"[\s,./()\"'%\-:;]+")


def tokenize(query: str) -> list[str]:
    # Разбиваем строку на «полезные» токены в нижнем регистре
    raw_parts = _SPLIT_RE.split(query.lower())
    tokens: list[str] = []
    seen: set[str] = set()
    for part in raw_parts:
        if len(part) < _MIN_TOKEN_LEN:
            continue
        # Отбрасываем чисто числовые и начинающиеся с цифры токены
        # (вроде "3,2", "950г" - единицы измерения и доли процентов).
        if part[0].isdigit():
            continue
        if part in seen:
            continue
        seen.add(part)
        tokens.append(part)
    return tokens


async def search_ingredients(
    db: AsyncSession,
    query: str,
    limit: int = 20,
) -> list[Ingredient]:
    # Ищем ингредиенты по словам из запроса, сортирует по релевантности.
    trimmed = query.strip()
    if not trimmed:
        result = await db.execute(
            select(Ingredient).order_by(Ingredient.name).limit(limit)
        )
        return list(result.scalars().all())

    tokens = tokenize(trimmed)

    # Если значимых токенов не получилось - fallback на простой LIKE.
    if not tokens:
        pattern = f"%{trimmed.lower()}%"
        stmt = (
            select(Ingredient)
            .where(func.lower(Ingredient.name).like(pattern))
            .order_by(func.length(Ingredient.name), Ingredient.name)
            .limit(limit)
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    # Считаем сумму совпавших токенов как score.
    score_expr = sum(
        case((func.lower(Ingredient.name).like(f"%{t}%"), 1), else_=0)
        for t in tokens
    )
    conditions = [func.lower(Ingredient.name).like(f"%{t}%") for t in tokens]

    stmt = (
        select(Ingredient, score_expr.label("score"))
        .where(or_(*conditions))
        .order_by(
            score_expr.desc(),
            func.length(Ingredient.name),
            Ingredient.name,
        )
        .limit(limit)
    )
    result = await db.execute(stmt)
    return [row[0] for row in result.all()]


async def find_best_match(
    db: AsyncSession,
    query: str,
) -> Optional[Ingredient]:
    """Возвращает наиболее подходящий ингредиент из БД или None.

    Стратегия в три шага, от уверенного к мягкому:
    1. Точное совпадение имени (case-insensitive).
    2. Имя ингредиента — одно слово, совпадающее с одним из значимых токенов
       запроса. Так «Молоко "Простоквашино" 3,2%» → «Молоко».
    3. Первое слово имени ингредиента есть среди значимых токенов запроса.
       Это покрывает многословные ингредиенты: «Сыр Российский 50%» → «Сыр
       твёрдый», «Соевый соус Kikkoman» → «Соевый соус».
       Ранжируем по количеству пересекающихся слов, потом по длине имени.

    Защита от ложных срабатываний: матч по 3-му шагу требует совпадения
    именно ПЕРВОГО слова ингредиента — это снижает риск ситуаций вроде
    «Газированная вода» → ошибочно сматчить с чем-то.
    """
    trimmed = query.strip()
    if not trimmed:
        return None

    # Точное совпадение имени (без учёта регистра)
    result = await db.execute(
        select(Ingredient).where(func.lower(Ingredient.name) == trimmed.lower())
    )
    exact = result.scalar_one_or_none()
    if exact:
        return exact

    tokens = tokenize(trimmed)
    if not tokens:
        return None
    tokens_set = set(tokens)

    # Имя ингредиента целиком - один из значимых токенов запроса.
    result = await db.execute(
        select(Ingredient).where(func.lower(Ingredient.name).in_(list(tokens)))
    )
    single_word_matches = list(result.scalars().all())
    if single_word_matches:
        single_word_matches.sort(key=lambda i: len(i.name))
        return single_word_matches[0]

    # Первое слово имени ингредиента есть среди значимых токенов запроса
    all_ings = (await db.execute(select(Ingredient))).scalars().all()
    candidates: list[tuple[int, int, Ingredient]] = []
    for ing in all_ings:
        ing_tokens = tokenize(ing.name)
        if not ing_tokens:
            continue
        # Требуем совпадения именно ПЕРВОГО слова имени ингредиента
        # (обычно это базовая категория продукта)
        if ing_tokens[0] not in tokens_set:
            continue
        overlap = sum(1 for w in ing_tokens if w in tokens_set)
        candidates.append((overlap, len(ing.name), ing))

    if not candidates:
        return None

    # Сортируем: больше пересечений сначала, потом короче имя
    candidates.sort(key=lambda c: (-c[0], c[1]))
    return candidates[0][2]
