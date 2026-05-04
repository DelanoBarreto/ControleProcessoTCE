
MOTIVO: 
Garantir que o codigo gerado atenda aos requisitos definidos e nao apenas 
"pareca funcionar".

GATILHO: 
Ativado quando o usuario pedir nova feature, endpoint ou funcao de negocio.

WORKFLOW OBRIGATORIO:
1. Red: Escreva testes que definem o comportamento esperado. 
   Eles DEVEM falhar inicialmente.
2. Green: Implemente o codigo minimo necessario para os testes passarem.
3. Refactor: Melhore a estrutura mantendo os testes verdes.

COBERTURA MINIMA:
- Funcoes de negocio: 80% de cobertura
- Edge cases obrigatorios: null/undefined, array vazio, strings vazias, 
  limites numericos
- Casos de erro: pelo menos 1 teste de excecao por funcao que pode falhar

EXEMPLO:
```python
# 1. PRIMEIRO: Escreva os testes
# tests/test_discount.py
import pytest
from app.services.pricing import calculate_discount, InvalidCouponError

class TestCalculateDiscount:
    def test_valid_coupon_applies_discount(self):
        assert calculate_discount(100.0, "SAVE10") == 90.0
    
    def test_no_coupon_returns_original_price(self):
        assert calculate_discount(100.0, None) == 100.0
    
    def test_invalid_coupon_raises_error(self):
        with pytest.raises(InvalidCouponError):
            calculate_discount(100.0, "FAKE123")
    
    def test_negative_price_raises_error(self):
        with pytest.raises(ValueError):
            calculate_discount(-50.0, "SAVE10")

# 2. DEPOIS: Implemente para passar os testes
# app/services/pricing.py
def calculate_discount(price: float, coupon_code: str | None) -> float:
    if price < 0:
        raise ValueError("Preco nao pode ser negativo")
    
    if not coupon_code:
        return price
    
    coupon = COUPONS.get(coupon_code.upper())
    if not coupon:
        raise InvalidCouponError(f"Cupom invalido: {coupon_code}")
    
    return price * (1 - coupon["discount"])
```

================================================================================