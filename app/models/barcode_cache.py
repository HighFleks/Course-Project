from sqlalchemy import Column, String, DateTime, Text
from sqlalchemy.sql import func
from app.database import Base

class BarcodeCache(Base):
    __tablename__ = "barcode_cache"

    barcode = Column(String, primary_key=True, index=True)
    product_name = Column(String, nullable=False)
    unit = Column(String, nullable=True)   # единица измерения, если удалось определить
    raw_data = Column(Text, nullable=True) # полный JSON-ответ от API (для отладки)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())