from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models.user import User
from app.models.recipe import Recipe
from app.models.favorite import FavoriteRecipe
from app.models.inventory import UserInventory
from app.models.shopping_list import ShoppingListItem
from app.schemas.user import (
    UserCreate, UserLogin, UserOut, Token,
    ChangePasswordRequest, UserStats,
)
from app.utils.security import verify_password, get_password_hash, create_access_token
from datetime import timedelta
from app.config import settings
from jose import JWTError, jwt

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/register", response_model=UserOut)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    # Проверяем, существует ли уже пользователь с таким email
    result = await db.execute(select(User).where(User.email == user_data.email))
    existing_user = result.scalar_one_or_none()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Хешируем пароль и создаём пользователя
    hashed_pwd = get_password_hash(user_data.password)
    new_user = User(email=user_data.email, hashed_password=hashed_pwd)
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user

@router.post("/login", response_model=Token)
async def login(user_data: UserLogin, db: AsyncSession = Depends(get_db)):
    # Ищем пользователя по email
    result = await db.execute(select(User).where(User.email == user_data.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(user_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Создаём токен с subject = user.id
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# Защищённый эндпоинт для получения информации о текущем пользователе
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()
    if user is None:
        raise credentials_exception
    return user

@router.get("/me", response_model=UserOut)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.get("/me/stats", response_model=UserStats)
async def get_my_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Возвращает счётчики активности текущего пользователя.
    recipes_created = await db.scalar(
        select(func.count(Recipe.id)).where(Recipe.created_by_user_id == current_user.id)
    )
    favorites_count = await db.scalar(
        select(func.count(FavoriteRecipe.id)).where(FavoriteRecipe.user_id == current_user.id)
    )
    inventory_items = await db.scalar(
        select(func.count(UserInventory.id)).where(UserInventory.user_id == current_user.id)
    )
    shopping_items = await db.scalar(
        select(func.count(ShoppingListItem.id)).where(ShoppingListItem.user_id == current_user.id)
    )
    return UserStats(
        recipes_created=recipes_created or 0,
        favorites_count=favorites_count or 0,
        inventory_items=inventory_items or 0,
        shopping_items=shopping_items or 0,
    )


@router.put("/me/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    payload: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Смена пароля: требует подтверждение текущего пароля.
    if not verify_password(payload.old_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Текущий пароль указан неверно")
    if payload.old_password == payload.new_password:
        raise HTTPException(status_code=400, detail="Новый пароль совпадает со старым")
    current_user.hashed_password = get_password_hash(payload.new_password)
    await db.commit()
    return