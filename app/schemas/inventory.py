from pydantic import BaseModel
from app.schemas.ingredient import IngredientOut

class InventoryItemBase(BaseModel):
    ingredient_id: int
    quantity: float

class InventoryItemCreate(InventoryItemBase):
    pass

class InventoryItemUpdate(BaseModel):
    quantity: float

class InventoryItemOut(InventoryItemBase):
    id: int
    ingredient: IngredientOut

    class Config:
        from_attributes = True