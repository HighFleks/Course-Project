from pydantic import BaseModel
from typing import Optional

class BarcodeLookupRequest(BaseModel):
    barcode: str

class BarcodeLookupResponse(BaseModel):
    barcode: str
    product_name: str
    unit: Optional[str] = None
    ingredient_id: int  # <-- ID ингредиента в нашем справочнике
    cached: bool = False