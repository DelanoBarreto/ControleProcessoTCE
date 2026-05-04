
MOTIVO: 
Codigo auto-documentado reduz overhead de manutencao e evita docs desatualizados.

GATILHO: 
Ativado ao criar funcoes, classes, modulos ou arquivos README.

HIERARQUIA DE CLAREZA:
1. Nomes Descritivos: Prefira user_email sobre ue, calculate_monthly_revenue 
   sobre calc.
2. Funcoes Pequenas: Cada funcao deve fazer UMA coisa. Se precisar de "e" 
   na descricao, quebre em duas.
3. Docstrings Obrigatorios: Toda funcao publica deve ter docstring com: 
   descricao, parametros, retorno, excecoes.
4. README Vivo: Deve conter: setup, exemplos de uso, arquitetura basica.

PROIBICOES:
- Comentarios que repetem o codigo (i += 1  # incrementa i)
- Codigo comentado (use git para historico)
- TODOs sem issue/ticket associado

EXEMPLO ERRADO:
```python
def calc(a, b, c, t):
    # calcula o valor
    x = a * b  # multiplica a por b
    if t:
        x = x - c  # subtrai c se t
    return x

# TODO: fix this later
# def old_calc():
#     ... 50 linhas comentadas ...
```

EXEMPLO CORRETO:
```python
def calculate_order_total(
    unit_price: Decimal,
    quantity: int,
    discount_amount: Decimal = Decimal("0"),
    apply_discount: bool = True
) -> Decimal:
    """
    Calcula o valor total de um pedido.
    
    Args:
        unit_price: Preco unitario do produto (deve ser >= 0)
        quantity: Quantidade de itens (deve ser >= 1)
        discount_amount: Valor absoluto do desconto a aplicar
        apply_discount: Se True, subtrai o desconto do total
    
    Returns:
        Valor total do pedido apos desconto (se aplicavel)
    
    Raises:
        ValueError: Se unit_price < 0 ou quantity < 1
    
    Example:
        >>> calculate_order_total(Decimal("10.00"), 3, Decimal("5.00"))
        Decimal("25.00")
    """
    if unit_price < 0:
        raise ValueError("Preco unitario nao pode ser negativo")
    if quantity < 1:
        raise ValueError("Quantidade deve ser pelo menos 1")
    
    subtotal = unit_price * quantity
    
    if apply_discount:
        return max(subtotal - discount_amount, Decimal("0"))
    
    return subtotal
```