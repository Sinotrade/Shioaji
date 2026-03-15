# Orders 下單

This document covers placing, modifying, and canceling orders in Shioaji.
本文件說明如何在 Shioaji 中下單、改單和刪單。

---

## Prerequisites 前置條件

Before placing orders, ensure CA is activated:
下單前請確認已啟用憑證：

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Activate CA 啟用憑證 (required 必須)
api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="YOUR_PASSWORD"
)
```

---

## Stock Orders 股票下單

### Basic Stock Order 基本股票下單

```python
contract = api.Contracts.Stocks["2330"]

order = api.Order(
    price=580,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    order_lot=sj.constant.StockOrderLot.Common,
    account=api.stock_account,
)

trade = api.place_order(contract, order)
```

### Order Parameters 訂單參數

| Parameter 參數 | Type 類型 | Description 說明 |
|----------------|-----------|------------------|
| `price` | float/int | Order price 委託價格 |
| `quantity` | int | Order quantity 委託數量 |
| `action` | Action | Buy/Sell 買/賣 |
| `price_type` | PriceType | LMT/MKT/MKP 限價/市價/範圍市價 |
| `order_type` | OrderType | ROD/IOC/FOK 委託條件 |
| `order_lot` | OrderLot | Common/Odd/IntradayOdd/Fixing 交易單位 |
| `order_cond` | OrderCond | Cash/MarginTrading/ShortSelling 信用條件 |
| `account` | Account | Trading account 交易帳戶 |
| `custom_field` | str | Memo (max 6 chars) 備註（最多6字元）|

### Market Order 市價單

```python
order = api.Order(
    price=0,  # Price ignored for MKT 市價單忽略價格
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.MKT,
    order_type=sj.constant.OrderType.IOC,  # MKT requires IOC/FOK 市價須 IOC/FOK
    account=api.stock_account,
)
```

### Odd Lot Orders 零股下單

```python
# Intraday odd lot 盤中零股 (9:00-13:30)
order = api.Order(
    price=580,
    quantity=100,  # Less than 1000 shares 小於1000股
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    order_lot=sj.constant.StockOrderLot.IntradayOdd,
    account=api.stock_account,
)

# After-hours odd lot 盤後零股 (13:40-14:30)
order = api.Order(
    price=580,
    quantity=100,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    order_lot=sj.constant.StockOrderLot.Odd,
    account=api.stock_account,
)
```

**Note 注意:** IntradayOdd orders cannot update price, only reduce quantity.
盤中零股委託不能改價，只能減量。

### Margin Trading 融資融券

```python
# Margin buy 融資買進
order = api.Order(
    price=580,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    order_cond=sj.constant.StockOrderCond.MarginTrading,
    account=api.stock_account,
)

# Short sell 融券賣出
order = api.Order(
    price=580,
    quantity=1,
    action=sj.constant.Action.Sell,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    order_cond=sj.constant.StockOrderCond.ShortSelling,
    account=api.stock_account,
)
```

### Day Trading 現股當沖

```python
# Day trade buy (first leg) 當沖買進（第一筆）
order = api.Order(
    price=580,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    daytrade_short=True,  # Enable day trade 啟用當沖
    account=api.stock_account,
)

# Day trade sell (close position) 當沖賣出（平倉）
order = api.Order(
    price=590,
    quantity=1,
    action=sj.constant.Action.Sell,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    daytrade_short=True,
    account=api.stock_account,
)
```

---

## Futures Orders 期貨下單

### Basic Futures Order 基本期貨下單

```python
contract = api.Contracts.Futures["TXFC0"]  # Current month 近月

order = api.Order(
    price=18000,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.FuturesPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    octype=sj.constant.FuturesOCType.Auto,  # Auto open/close 自動開平
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

### Futures Parameters 期貨參數

| Parameter 參數 | Type 類型 | Description 說明 |
|----------------|-----------|------------------|
| `price` | float/int | Order price 委託價格 |
| `quantity` | int | Number of contracts 口數 |
| `action` | Action | Buy/Sell 買/賣 |
| `price_type` | FuturesPriceType | LMT/MKT/MKP 限價/市價/範圍市價 |
| `order_type` | OrderType | ROD/IOC/FOK 委託條件 |
| `octype` | FuturesOCType | Auto/NewPosition/Cover 自動/新倉/平倉 |
| `account` | Account | Futures account 期貨帳戶 |

### Open/Close Type 開平倉類型

```python
sj.constant.FuturesOCType.Auto        # Auto 自動 (recommended 推薦)
sj.constant.FuturesOCType.NewPosition # Open new 新倉
sj.constant.FuturesOCType.Cover       # Close 平倉
sj.constant.FuturesOCType.DayTrade    # Day trade 當沖
```

---

## Options Orders 選擇權下單

### Basic Options Order 基本選擇權下單

```python
# Buy call option 買進買權
contract = api.Contracts.Options["TXO202401C18000"]

order = api.Order(
    price=100,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.FuturesPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    octype=sj.constant.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

### Sell Options 賣出選擇權

```python
# Sell put option 賣出賣權
contract = api.Contracts.Options["TXO202401P17000"]

order = api.Order(
    price=50,
    quantity=1,
    action=sj.constant.Action.Sell,
    price_type=sj.constant.FuturesPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    octype=sj.constant.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

---

## Combo Orders 組合單

Combo orders allow trading multi-leg option strategies (spreads, straddles, strangles).
組合單可交易多腳選擇權策略（價差、跨式、勒式等）。

### Create Combo Contract 建立組合合約

```python
from shioaji.contracts import ComboContract, ComboBase

# Bull Call Spread 買權多頭價差
# Buy lower strike, Sell higher strike
# 買進較低履約價，賣出較高履約價
combo_contract = ComboContract(
    legs=[
        ComboBase(
            action=sj.constant.Action.Buy,
            contract=api.Contracts.Options["TXO202401C18000"],
        ),
        ComboBase(
            action=sj.constant.Action.Sell,
            contract=api.Contracts.Options["TXO202401C18500"],
        ),
    ]
)
```

### Place Combo Order 下組合單

```python
combo_order = api.ComboOrder(
    price=50,  # Net price 淨價
    quantity=1,
    price_type=sj.constant.FuturesPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    octype=sj.constant.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_comboorder(combo_contract, combo_order)
```

### Combo Order Parameters 組合單參數

| Parameter 參數 | Type 類型 | Description 說明 |
|----------------|-----------|------------------|
| `price` | float | Net price of spread 價差淨價 |
| `quantity` | int | Number of combos 組數 |
| `price_type` | FuturesPriceType | LMT/MKT 限價/市價 |
| `order_type` | OrderType | ROD/IOC/FOK 委託條件 |
| `octype` | FuturesOCType | Auto/NewPosition/Cover 開平倉 |

### Strategy Examples 策略範例

```python
# Straddle 跨式 (Buy Call + Buy Put same strike)
straddle = ComboContract(
    legs=[
        ComboBase(
            action=sj.constant.Action.Buy,
            contract=api.Contracts.Options["TXO202401C18000"],
        ),
        ComboBase(
            action=sj.constant.Action.Buy,
            contract=api.Contracts.Options["TXO202401P18000"],
        ),
    ]
)

# Strangle 勒式 (Buy OTM Call + Buy OTM Put)
strangle = ComboContract(
    legs=[
        ComboBase(
            action=sj.constant.Action.Buy,
            contract=api.Contracts.Options["TXO202401C18500"],
        ),
        ComboBase(
            action=sj.constant.Action.Buy,
            contract=api.Contracts.Options["TXO202401P17500"],
        ),
    ]
)
```

### Combo Status 組合單狀態

```python
# Update combo status 更新組合單狀態
api.update_combostatus(api.futopt_account)

# List all combo trades 列出所有組合單
combo_trades = api.list_combotrades()

for trade in combo_trades:
    print(f"Order ID: {trade.order.id}")
    print(f"Status: {trade.status.status}")
```

### Cancel Combo Order 取消組合單

```python
api.cancel_comboorder(trade)
```

---

## Modify Orders 改單

### Change Price 改價

```python
api.update_order(trade=trade, price=585)
```

### Reduce Quantity 減量

Note: Can only reduce, not increase.
注意：只能減少，不能增加。

```python
api.update_order(trade=trade, qty=1)
```

---

## Cancel Orders 刪單

```python
api.cancel_order(trade)

# Or cancel by trade object 或透過 trade 物件
api.cancel_order(trade=trade)
```

---

## Order Status 訂單狀態

### Update Status 更新狀態

```python
# Update all order status 更新所有訂單狀態
api.update_status(api.stock_account)
api.update_status(api.futopt_account)
```

### List Trades 列出交易

```python
# List all trades 列出所有交易
trades = api.list_trades()

for trade in trades:
    print(f"Order: {trade.order.id}")
    print(f"Status: {trade.status.status}")
    print(f"Deal Quantity: {trade.status.deal_quantity}")
```

### Trade Status Values 交易狀態值

| Status 狀態 | Description 說明 |
|-------------|------------------|
| `PendingSubmit` | Submitting 傳送中 |
| `PreSubmitted` | Pre-submitted 預約中 |
| `Submitted` | Submitted 已送出 |
| `Failed` | Failed 失敗 |
| `Cancelled` | Cancelled 已取消 |
| `Filled` | Fully filled 全部成交 |
| `PartFilled` | Partially filled 部分成交 |

### Trade Object Attributes 交易物件屬性

```python
trade.contract        # Contract 合約
trade.order           # Order details 訂單詳情
trade.order.id        # Order ID 訂單編號
trade.order.seqno     # Sequence number 序號
trade.order.action    # Buy/Sell 買賣方向
trade.order.price     # Order price 委託價
trade.order.quantity  # Order quantity 委託量
trade.status          # Status object 狀態物件
trade.status.status   # Status value 狀態值
trade.status.deal_quantity  # Filled quantity 成交量
trade.status.cancel_quantity # Cancelled quantity 取消量
```

---

## Order Callbacks 訂單回報

Order and deal events are pushed automatically when orders are submitted or filled.
委託及成交事件會在下單或成交時主動推送。

### Set Order Callback 設定回報 Callback

```python
def order_cb(stat, msg):
    print(f"State: {stat}")
    print(f"Message: {msg}")

api.set_order_callback(order_cb)
```

### OrderState Types 回報狀態類型

```python
import shioaji as sj

# Stock 股票
sj.constant.OrderState.StockOrder  # 股票委託回報
sj.constant.OrderState.StockDeal   # 股票成交回報

# Futures/Options 期貨選擇權
sj.constant.OrderState.FuturesOrder  # 期貨委託回報
sj.constant.OrderState.FuturesDeal   # 期貨成交回報
```

### TypedDict Definitions 類型定義

For better type hints, use these TypedDict definitions:
使用以下 TypedDict 定義以獲得更好的型別提示：

```python
from typing import TypedDict, Literal

class OperationDict(TypedDict):
    op_type: Literal["New", "Cancel", "UpdatePrice", "UpdateQty"]
    op_code: str  # "00" = success, others = fail
    op_msg: str

class AccountDict(TypedDict):
    account_type: Literal["S", "F"]  # S=Stock, F=Futures
    person_id: str
    broker_id: str
    account_id: str
    signed: bool

class StockOrderDict(TypedDict):
    id: str
    seqno: str
    ordno: str
    account: AccountDict
    action: Literal["Buy", "Sell"]
    price: float
    quantity: int
    order_type: Literal["ROD", "IOC", "FOK"]
    price_type: Literal["LMT", "MKT", "MKP"]
    order_cond: Literal["Cash", "MarginTrading", "ShortSelling"]
    order_lot: Literal["Common", "Odd", "IntradayOdd", "Fixing"]
    custom_field: str

class OrderStatusDict(TypedDict):
    id: str
    exchange_ts: float
    modified_price: float
    cancel_quantity: int
    order_quantity: int
    web_id: str

class StockContractDict(TypedDict):
    security_type: Literal["STK"]
    exchange: str
    code: str
    symbol: str
    name: str
    currency: str

class StockOrderEvent(TypedDict):
    operation: OperationDict
    order: StockOrderDict
    status: OrderStatusDict
    contract: StockContractDict

class StockDealEvent(TypedDict):
    trade_id: str
    seqno: str
    ordno: str
    exchange_seq: str
    broker_id: str
    account_id: str
    action: Literal["Buy", "Sell"]
    code: str
    order_cond: Literal["Cash", "MarginTrading", "ShortSelling"]
    order_lot: Literal["Common", "Odd", "IntradayOdd", "Fixing"]
    price: float
    quantity: int
    web_id: str
    custom_field: str
    ts: float

class FuturesOrderDict(TypedDict):
    id: str
    seqno: str
    ordno: str
    account: AccountDict
    action: Literal["Buy", "Sell"]
    price: float
    quantity: int
    order_type: Literal["ROD", "IOC", "FOK"]
    price_type: Literal["LMT", "MKT", "MKP"]
    market_type: Literal["Day", "Night"]
    oc_type: Literal["New", "Cover", "Auto"]
    subaccount: str
    combo: bool

class FuturesContractDict(TypedDict):
    security_type: Literal["FUT", "OPT"]
    code: str
    full_code: str
    exchange: str
    delivery_month: str
    delivery_date: str
    strike_price: float
    option_right: Literal["Future", "OptionCall", "OptionPut"]

class FuturesOrderEvent(TypedDict):
    operation: OperationDict
    order: FuturesOrderDict
    status: OrderStatusDict
    contract: FuturesContractDict

class FuturesDealEvent(TypedDict):
    trade_id: str
    seqno: str
    ordno: str
    exchange_seq: str
    broker_id: str
    account_id: str
    action: Literal["Buy", "Sell"]
    code: str
    full_code: str
    price: float
    quantity: int
    subaccount: str
    security_type: Literal["FUT", "OPT"]
    delivery_month: str
    strike_price: float
    option_right: Literal["Future", "OptionCall", "OptionPut"]
    market_type: Literal["Day", "Night"]
    combo: bool
    ts: float
```

### Handle Different Events 處理不同事件

Split handlers by event type for clear type hints:
依事件類型拆分 handler 以獲得明確的型別提示：

```python
import shioaji as sj
from shioaji.constant import OrderState

def stock_order_handler(event: StockOrderEvent):
    """Handle stock order event 處理股票委託回報"""
    op = event["operation"]
    order = event["order"]
    if op["op_code"] == "00":
        print(f"Stock order {op['op_type']} success: {order['id']}")
    else:
        print(f"Stock order failed: {op['op_msg']}")

def stock_deal_handler(deal: StockDealEvent):
    """Handle stock deal event 處理股票成交回報"""
    print(f"Stock deal: {deal['code']} @ {deal['price']} x {deal['quantity']}")

def futures_order_handler(event: FuturesOrderEvent):
    """Handle futures order event 處理期貨委託回報"""
    op = event["operation"]
    order = event["order"]
    contract = event["contract"]
    if op["op_code"] == "00":
        print(f"Futures order {op['op_type']}: {order['action']} {contract['code']}")
    else:
        print(f"Futures order failed: {op['op_msg']}")

def futures_deal_handler(deal: FuturesDealEvent):
    """Handle futures deal event 處理期貨成交回報"""
    print(f"Futures deal: {deal['code']} @ {deal['price']} x {deal['quantity']}")

def order_cb(stat: OrderState, msg: dict):
    """Main callback dispatcher 主回調分發器"""
    if stat == OrderState.StockOrder:
        stock_order_handler(msg)
    elif stat == OrderState.StockDeal:
        stock_deal_handler(msg)
    elif stat == OrderState.FuturesOrder:
        futures_order_handler(msg)
    elif stat == OrderState.FuturesDeal:
        futures_deal_handler(msg)

api.set_order_callback(order_cb)
```

### Note 注意事項

Deal events may arrive before order events due to exchange message priority.
成交回報可能比委託回報更早到達，因為交易所訊息優先順序不同。

---

## Best Practices 最佳實踐

### 1. Use Callbacks for Real-time Status 使用主動回報獲取即時狀態

Prefer callbacks over `update_status()` to avoid rate limits.
優先使用主動回報而非 `update_status()` 以避免觸發流量限制。

```python
def order_cb(stat: OrderState, msg: dict):
    if stat == OrderState.StockOrder:
        if msg["operation"]["op_code"] == "00":
            print(f"Order accepted: {msg['order']['id']}")
        else:
            print(f"Order rejected: {msg['operation']['op_msg']}")
    elif stat == OrderState.StockDeal:
        print(f"Filled: {msg['code']} @ {msg['price']} x {msg['quantity']}")

api.set_order_callback(order_cb)
```

### 2. Use update_status Only When Needed 僅在必要時使用 update_status

Only use `update_status()` for:
僅在以下情況使用 `update_status()`：

- After reconnection 斷線重連後
- Query historical orders 查詢歷史訂單
- When callback missed 回報遺漏時

```python
# Query specific trade only 僅查詢特定訂單
api.update_status(trade=trade)

# Or query all (use sparingly) 或查詢全部（謹慎使用）
api.update_status(api.stock_account)
```

### 3. Handle Errors Gracefully 優雅處理錯誤

```python
try:
    trade = api.place_order(contract, order)
except Exception as e:
    print(f"Order error: {e}")
