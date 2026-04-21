from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.schemas.ingredient import IngredientOut

# --- Ингредиент в составе рецепта ---
class RecipeIngredientBase(BaseModel):
    ingredient_id: int
    quantity: float

class RecipeIngredientCreate(RecipeIngredientBase):
    pass

class RecipeIngredientOut(RecipeIngredientBase):
    id: int
    ingredient: IngredientOut  # чтобы фронтенд мог показать название и единицу

    class Config:
        from_attributes = True

# --- Рецепт ---
class RecipeBase(BaseModel):
    name: str
    description: Optional[str] = None
    instructions: Optional[str] = None
    image_url: Optional[str] = None
    category: Optional[str] = None
    is_public: bool = True

class RecipeCreate(RecipeBase):
    ingredients: List[RecipeIngredientCreate] = []  # список ингредиентов при создании

class RecipeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    instructions: Optional[str] = None
    image_url: Optional[str] = None
    category: Optional[str] = None
    is_public: Optional[bool] = None
    ingredients: Optional[List[RecipeIngredientCreate]] = None

class RecipeOut(RecipeBase):
    id: int
    created_by_user_id: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    ingredients: List[RecipeIngredientOut] = []

    class Config:
        from_attributes = True