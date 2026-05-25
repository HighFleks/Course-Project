from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field

# Запрос на регистрацию
class UserCreate(BaseModel):
    email: EmailStr
    password: str

# Запрос на вход
class UserLogin(BaseModel):
    email: EmailStr
    password: str

# Ответ с данными пользователя (без пароля)
class UserOut(BaseModel):
    id: int
    email: EmailStr
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True  # для совместимости с ORM

# Ответ с JWT токеном
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

# Запрос на смену пароля
class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6)

# Статистика пользователя
class UserStats(BaseModel):
    recipes_created: int
    favorites_count: int
    inventory_items: int
    shopping_items: int