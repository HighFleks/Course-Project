import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from app.config import settings
from app.models.ingredient import Ingredient
from app.models.recipe import Recipe, RecipeIngredient
from app.models.user import User
from app.utils.security import get_password_hash

DATABASE_URL = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def init_data():
    async with AsyncSessionLocal() as db:
        # 1. Создаём тестового пользователя (если ещё нет)
        test_user_email = "demo@example.com"
        result = await db.execute(select(User).where(User.email == test_user_email))
        user = result.scalar_one_or_none()
        if not user:
            user = User(
                email=test_user_email,
                hashed_password=get_password_hash("demo123")
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
            print(f"✅ Создан тестовый пользователь: {test_user_email} / demo123")
        else:
            print(f"ℹ️ Пользователь {test_user_email} уже существует")

        # 2. Список базовых ингредиентов
        ingredients_data = [
            {"name": "Мука пшеничная", "unit": "г"},
            {"name": "Молоко", "unit": "мл"},
            {"name": "Яйцо куриное", "unit": "шт"},
            {"name": "Сахар", "unit": "г"},
            {"name": "Соль", "unit": "г"},
            {"name": "Масло растительное", "unit": "мл"},
            {"name": "Картофель", "unit": "г"},
            {"name": "Морковь", "unit": "г"},
            {"name": "Лук репчатый", "unit": "г"},
            {"name": "Помидор", "unit": "г"},
            {"name": "Огурец", "unit": "г"},
            {"name": "Сметана", "unit": "г"},
            {"name": "Творог", "unit": "г"},
            {"name": "Крупа гречневая", "unit": "г"},
            {"name": "Рис", "unit": "г"},
            {"name": "Макароны", "unit": "г"},
            {"name": "Куриное филе", "unit": "г"},
            {"name": "Сыр", "unit": "г"},
        ]

        ingredient_map = {}
        for ing_data in ingredients_data:
            result = await db.execute(select(Ingredient).where(Ingredient.name == ing_data["name"]))
            ing = result.scalar_one_or_none()
            if not ing:
                ing = Ingredient(**ing_data)
                db.add(ing)
                await db.flush()
            ingredient_map[ing.name] = ing
        await db.commit()
        print(f"✅ Загружено {len(ingredient_map)} ингредиентов")

        # 3. Создаём несколько рецептов
        recipes_to_create = []

        # Рецепт 1: Блинчики
        blinchiki = {
            "name": "Блинчики на молоке",
            "description": "Тонкие, нежные блинчики",
            "instructions": "1. Смешайте яйца, сахар и соль.\n2. Добавьте молоко, перемешайте.\n3. Постепенно всыпьте муку, размешивая до однородности.\n4. Добавьте растительное масло.\n5. Жарьте на разогретой сковороде с двух сторон.",
            "category": "завтрак",
            "is_public": True,
            "created_by_user_id": user.id,
            "ingredients": [
                {"ingredient": ingredient_map["Мука пшеничная"], "quantity": 200},
                {"ingredient": ingredient_map["Молоко"], "quantity": 500},
                {"ingredient": ingredient_map["Яйцо куриное"], "quantity": 2},
                {"ingredient": ingredient_map["Сахар"], "quantity": 30},
                {"ingredient": ingredient_map["Соль"], "quantity": 5},
                {"ingredient": ingredient_map["Масло растительное"], "quantity": 30},
            ]
        }

        # Рецепт 2: Омлет
        omlet = {
            "name": "Омлет с помидорами",
            "description": "Пышный омлет с сочными помидорами",
            "instructions": "1. Взбейте яйца с молоком и солью.\n2. Нарежьте помидоры.\n3. Вылейте яичную смесь на разогретую сковороду, сверху выложите помидоры.\n4. Жарьте под крышкой 5-7 минут.",
            "category": "завтрак",
            "is_public": True,
            "created_by_user_id": user.id,
            "ingredients": [
                {"ingredient": ingredient_map["Яйцо куриное"], "quantity": 3},
                {"ingredient": ingredient_map["Молоко"], "quantity": 50},
                {"ingredient": ingredient_map["Помидор"], "quantity": 100},
                {"ingredient": ingredient_map["Соль"], "quantity": 3},
                {"ingredient": ingredient_map["Масло растительное"], "quantity": 10},
            ]
        }

        # Рецепт 3: Гречка с курицей
        grechka = {
            "name": "Гречка с куриным филе",
            "description": "Сытное и полезное блюдо",
            "instructions": "1. Отварите гречневую крупу.\n2. Куриное филе нарежьте кубиками и обжарьте с луком и морковью.\n3. Смешайте гречку с курицей и овощами.",
            "category": "обед",
            "is_public": True,
            "created_by_user_id": user.id,
            "ingredients": [
                {"ingredient": ingredient_map["Крупа гречневая"], "quantity": 200},
                {"ingredient": ingredient_map["Куриное филе"], "quantity": 300},
                {"ingredient": ingredient_map["Лук репчатый"], "quantity": 100},
                {"ingredient": ingredient_map["Морковь"], "quantity": 100},
                {"ingredient": ingredient_map["Масло растительное"], "quantity": 20},
                {"ingredient": ingredient_map["Соль"], "quantity": 5},
            ]
        }

        recipes_to_create.extend([blinchiki, omlet, grechka])

        for rec_data in recipes_to_create:
            # Проверим, нет ли уже рецепта с таким названием у этого пользователя
            existing = await db.execute(
                select(Recipe).where(
                    Recipe.name == rec_data["name"],
                    Recipe.created_by_user_id == user.id
                )
            )
            if existing.scalar_one_or_none():
                print(f"ℹ️ Рецепт '{rec_data['name']}' уже существует, пропускаем")
                continue

            recipe = Recipe(
                name=rec_data["name"],
                description=rec_data["description"],
                instructions=rec_data["instructions"],
                category=rec_data["category"],
                is_public=rec_data["is_public"],
                created_by_user_id=rec_data["created_by_user_id"]
            )
            db.add(recipe)
            await db.flush()

            for ing_info in rec_data["ingredients"]:
                rec_ing = RecipeIngredient(
                    recipe_id=recipe.id,
                    ingredient_id=ing_info["ingredient"].id,
                    quantity=ing_info["quantity"]
                )
                db.add(rec_ing)

            await db.commit()
            print(f"✅ Создан рецепт: {rec_data['name']}")

        print("\n🎉 Инициализация тестовых данных завершена!")
        print(f"   Логин: {test_user_email}")
        print("   Пароль: demo123")


if __name__ == "__main__":
    asyncio.run(init_data())