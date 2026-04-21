from pydantic import BaseModel
from app.schemas.ingredient import IngredientOut

class ShoppingListItemBase(BaseModel):
    ingredient_id: int
    quantity: float

class ShoppingListItemCreate(ShoppingListItemBase):
    pass

class ShoppingListItemUpdate(BaseModel):
    quantity: float | None = None
    is_purchased: bool | None = None

class ShoppingListItemOut(ShoppingListItemBase):
    id: int
    is_purchased: bool
    ingredient: IngredientOut

    class Config:
        from_attributes = True

class GenerateShoppingListRequest(BaseModel):
    recipe_ids: list[int]