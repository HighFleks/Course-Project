from pydantic import BaseModel, EmailStr

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

    class Config:
        from_attributes = True  # для совместимости с ORM

# Ответ с JWT токеном
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"