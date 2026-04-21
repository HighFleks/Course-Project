from sqlalchemy import Column, Integer, String, Text, ForeignKey, Float, DateTime, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Recipe(Base):
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    instructions = Column(Text, nullable=True)  # шаги приготовления
    image_url = Column(String, nullable=True)
    category = Column(String, nullable=True)   # завтрак, обед, ужин и т.д.
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # NULL = общий рецепт
    is_public = Column(Boolean, default=True)  # публичный или пользовательский
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    created_by = relationship("User", backref="own_recipes")
    ingredients = relationship("RecipeIngredient", back_populates="recipe", cascade="all, delete-orphan")


class RecipeIngredient(Base):
    __tablename__ = "recipe_ingredients"

    id = Column(Integer, primary_key=True, index=True)
    recipe_id = Column(Integer, ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id", ondelete="CASCADE"), nullable=False)
    quantity = Column(Float, nullable=False)  # количество (например 200.0)

    # Связи
    recipe = relationship("Recipe", back_populates="ingredients")
    ingredient = relationship("Ingredient", backref="recipe_ingredients")