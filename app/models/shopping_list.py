from sqlalchemy import Column, Integer, ForeignKey, Float, Boolean, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base

class ShoppingListItem(Base):
    __tablename__ = "shopping_list_items"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id", ondelete="CASCADE"), nullable=False)
    quantity = Column(Float, nullable=False)
    is_purchased = Column(Boolean, default=False)

    __table_args__ = (UniqueConstraint("user_id", "ingredient_id", name="uq_shopping_list_item"),)

    user = relationship("User", backref="shopping_list")
    ingredient = relationship("Ingredient")