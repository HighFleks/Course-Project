from sqlalchemy import Column, Integer, String
from app.database import Base

class Ingredient(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False, index=True)
    unit = Column(String, nullable=False, default="г")  # г, мл, шт, ст.л., ч.л. и т.д.