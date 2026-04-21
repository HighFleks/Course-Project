from pydantic import BaseModel

class IngredientBase(BaseModel):
    name: str
    unit: str = "г"

class IngredientCreate(IngredientBase):
    pass

class IngredientOut(IngredientBase):
    id: int

    class Config:
        from_attributes = True