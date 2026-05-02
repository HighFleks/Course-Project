from pydantic import BaseModel

class FavoriteCreate(BaseModel):
    recipe_id: int

class FavoriteOut(BaseModel):
    id: int
    user_id: int
    recipe_id: int

    class Config:
        from_attributes = True