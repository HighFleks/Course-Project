from sqlalchemy import Column, Integer, ForeignKey, Float, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base

class UserInventory(Base):
    __tablename__ = "user_inventory"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id", ondelete="CASCADE"), nullable=False)
    quantity = Column(Float, nullable=False, default=0.0)

    # Уникальность: у одного пользователя не может быть двух записей для одного ингредиента
    __table_args__ = (UniqueConstraint("user_id", "ingredient_id", name="uq_user_inventory"),)

    # Связи
    user = relationship("User", backref="inventory")
    ingredient = relationship("Ingredient", backref="inventory_items")