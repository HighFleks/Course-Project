from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.config import settings

# Заменяем postgresql:// на postgresql+asyncpg:// для асинхронного драйвера
DATABASE_URL = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()  # базовый класс для моделей

async def get_db():
    """Зависимость для получения сессии БД в эндпоинтах."""
    async with AsyncSessionLocal() as session:
        yield session