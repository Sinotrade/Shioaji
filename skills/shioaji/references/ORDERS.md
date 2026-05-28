# Orders 下單

This document covers placing, modifying, and canceling orders in Shioaji.
本文件說明如何在 Shioaji 中下單、改單和刪單。

Use [MIGRATION.md](MIGRATION.md) when migrating legacy order constructors or submodule constants. This file owns `Trade`, `Vec<Trade>`, `ComboTrade`, `PendingSubmit`, and order-event response decisions.

## Table of Contents 目錄

- [Prerequisites 前置條件](#prerequisites-前置條件)
- [Stock Orders 股票下單](#stock-orders-股票下單)
- [Futures Orders 期貨下單](#futures-orders-期貨下單)
- [Options Orders 選擇權下單](#options-orders-選擇權下單)
- [Combo Orders 組合單](#combo-orders-組合單)
- [Modify Orders 改單](#modify-orders-改單)
- [Cancel Orders 刪單](#cancel-orders-刪單)
- [Order Status 訂單狀態](#order-status-訂單狀態)
- [Order Deal Records 委託成交紀錄](#order-deal-records-委託成交紀錄)
- [Order Callbacks 訂單回報](#order-callbacks-訂單回報)
- [Subscribe/Unsubscribe Trade 訂閱/取消訂閱交易回報](#subscribeunsubscribe-trade-訂閱取消訂閱交易回報)
- [Best Practices 最佳實踐](#best-practices-最佳實踐)

---

## Prerequisites 前置條件

Before placing **production** orders, ensure CA is activated. Simulation orders skip CA signing automatically.
正式環境下單前請確認已啟用憑證；模擬下單會自動跳過 CA 簽章。

```python
import shioaji as sj

api = sj.Shioaji(simulation=False)
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Activate CA 啟用憑證 (required for production orders 正式下單必要)
api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="YOUR_PASSWORD"
)
```

---

## Stock Orders 股票下單

Python order examples below assume login is complete and contract files are ready. For full scripts, load contracts with `contracts_timeout` (sync) or `fetch_contracts()` (async), choose simulation/production intentionally, activate CA for production orders, and always inspect `trade.status.status` after `place_order()`.
以下 Python 下單範例假設已完成登入且商品檔已載入。完整程式請用 `contracts_timeout`（sync）或 `fetch_contracts()`（async）載入商品檔，明確選擇 simulation/production，正式下單前啟用 CA，並在 `place_order()` 後檢查 `trade.status.status`。

`place_order()` returns a `Trade`, but the first returned status can be `PendingSubmit` (`傳送中`). Treat `PendingSubmit` as an intermediate state, not a final exchange acknowledgement. To know whether the order became `Submitted`, `Filled`, `PartFilled`, `Failed`, or `Cancelled`, prefer waiting for active order/deal reports first: Python order callbacks or HTTP order-event SSE. Use `api.update_status(trade=trade)` / `api.update_status(account)` when callbacks/SSE are unavailable, were missed, or a reconciliation check is needed.
`place_order()` 會回 `Trade`，但第一次回來的狀態可能是 `PendingSubmit`（傳送中）。請把 `PendingSubmit` 視為中間狀態，不是交易所最終確認。若要知道是否變成 `Submitted`、`Filled`、`PartFilled`、`Failed` 或 `Cancelled`，優先等待主動委託/成交回報：Python order callback 或 HTTP order-event SSE。只有在無法使用 callback/SSE、疑似漏回報或需要對帳補查時，才用 `api.update_status(trade=trade)` / `api.update_status(account)`。

### Basic Stock Order 基本股票下單

```python
contract = api.Contracts.Stocks["2330"]

order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_lot=sj.StockOrderLot.Common,
    account=api.stock_account,
)

trade = api.place_order(contract, order)
print(trade.status.status)

if trade.status.status == sj.OrderStatus.PendingSubmit:
    # Prefer active order callbacks/SSE; use update_status for reconciliation.
    # 優先等主動回報；需要補查或對帳時再用 update_status。
    api.update_status(trade=trade)
    print(trade.status.status)
```

#### HTTP: Place Stock Order

Omit `account` to use the default signed stock account, or supply
`{broker_id, account_id}` to target a specific one. The server fills
in the remaining account fields from the login session (1.5.12+,
#234).

```bash
# POST /api/v1/order/place_order
curl -X POST http://localhost:8080/api/v1/order/place_order \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "STK", "exchange": "TSE", "code": "2330"},
    "stock_order": {
      "price": 580,
      "quantity": 1,
      "action": "Buy",
      "price_type": "LMT",
      "order_type": "ROD",
      "order_lot": "Common",
      "order_cond": "Cash",
      "account": {"broker_id": "9A95", "account_id": "1234567"}
    }
  }'
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

> **TWSE accepts every `price_type` × `order_type` combination** — MKT/LMT/MKP each pair with ROD/IOC/FOK. This differs from TAIFEX; see [Futures Parameters](#futures-parameters-期貨參數).
> **證交所所有 `price_type` × `order_type` 組合皆有效** — MKT/LMT/MKP 都可搭配 ROD/IOC/FOK；與期交所限制不同。

### Market Order 市價單

```python
order = sj.StockOrder(
    price=0,  # Price ignored for MKT 市價單忽略價格
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.MKT,
    order_type=sj.OrderType.ROD,  # Stocks: MKT accepts ROD/IOC/FOK 股票市價可搭配 ROD/IOC/FOK
    account=api.stock_account,
)
```

### Odd Lot Orders 零股下單

```python
# Intraday odd lot 盤中零股 (9:00-13:30)
order = sj.StockOrder(
    price=580,
    quantity=100,  # Less than 1000 shares 小於1000股
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_lot=sj.StockOrderLot.IntradayOdd,
    account=api.stock_account,
)

# After-hours odd lot 盤後零股 (13:40-14:30)
order = sj.StockOrder(
    price=580,
    quantity=100,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_lot=sj.StockOrderLot.Odd,
    account=api.stock_account,
)
```

**Note 注意:** IntradayOdd orders cannot update price, only reduce quantity.
盤中零股委託不能改價，只能減量。

### Margin Trading 融資融券

```python
# Margin buy 融資買進
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_cond=sj.StockOrderCond.MarginTrading,
    account=api.stock_account,
)

# Short sell 融券賣出
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_cond=sj.StockOrderCond.ShortSelling,
    account=api.stock_account,
)
```

### Day Trading 現股當沖

```python
# Day trade buy (first leg) 當沖買進（第一筆）
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    daytrade_short=True,  # Enable day trade 啟用當沖
    account=api.stock_account,
)

# Day trade sell (close position) 當沖賣出（平倉）
order = sj.StockOrder(
    price=590,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    daytrade_short=True,
    account=api.stock_account,
)
```

---

## Futures Orders 期貨下單

### Basic Futures Order 基本期貨下單

```python
contract = api.Contracts.Futures["TXFC0"]  # Current month 近月

order = sj.FuturesOrder(
    price=18000,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,  # Auto open/close 自動開平
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
print(trade.status.status)

if trade.status.status == sj.OrderStatus.PendingSubmit:
    # Prefer active order callbacks/SSE; use update_status for reconciliation.
    # 優先等主動回報；需要補查或對帳時再用 update_status。
    api.update_status(trade=trade)
    print(trade.status.status)
```

#### HTTP: Place Futures Order

Same partial-account selector applies: `{"broker_id":"F002", "account_id":"1234567"}` targets a specific futures account; omit for default.

```bash
# POST /api/v1/order/place_order
curl -X POST http://localhost:8080/api/v1/order/place_order \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "FUT", "exchange": "TAIFEX", "code": "TXFC0"},
    "futures_order": {
      "price": 18000,
      "quantity": 1,
      "action": "Buy",
      "price_type": "LMT",
      "order_type": "ROD",
      "octype": "Auto",
      "account": {"broker_id": "F002", "account_id": "1234567"}
    }
  }'
```

### Futures Parameters 期貨參數

| Parameter 參數 | Type 類型 | Description 說明 |
|----------------|-----------|------------------|
| `price` | float/int | Order price 委託價格 |
| `quantity` | int | Number of contracts 口數 |
| `action` | Action | Buy/Sell 買/賣 |
| `price_type` | FuturesPriceType | LMT/MKT/MKP 限價/市價/範圍市價 |
| `order_type` | OrderType | ROD/IOC/FOK 委託條件 |
| `octype` | FuturesOCType | Auto/New/Cover/DayTrade 自動/新倉/平倉/當沖 |
| `account` | Account | Futures account 期貨帳戶 |

> **TAIFEX rejects `MKT` + `ROD`** — on futures/options, MKT must pair with IOC or FOK (server returns `op_code` 9938). LMT and MKP accept ROD/IOC/FOK.
> **期交所拒絕 `MKT` + `ROD`** — 期貨/選擇權市價單必須搭配 IOC 或 FOK（伺服器回 `op_code` 9938 退單）；LMT、MKP 則三種委託條件皆可。

### Open/Close Type 開平倉類型

```python
sj.FuturesOCType.Auto        # Auto 自動 (recommended 推薦)
sj.FuturesOCType.New         # Open new 新倉
sj.FuturesOCType.Cover       # Close 平倉
sj.FuturesOCType.DayTrade    # Day trade 當沖
```

HTTP accepts both `"New"` and `"NewPosition"` for compatibility, but Python exposes `sj.FuturesOCType.New`.

---

## Options Orders 選擇權下單

### Basic Options Order 基本選擇權下單

```python
# Buy call option 買進買權
contract = api.Contracts.Options["TXO202401C18000"]

order = sj.FuturesOrder(
    price=100,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

### Sell Options 賣出選擇權

```python
# Sell put option 賣出賣權
contract = api.Contracts.Options["TXO202401P17000"]

order = sj.FuturesOrder(
    price=50,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

---

## Combo Orders 組合單

Combo orders allow trading multi-leg strategies: calendar spreads, option spreads, straddles, strangles.
組合單可交易多腳策略（期貨日曆價差、選擇權價差、跨式、勒式等）。

**Exactly 2 legs are required.** The client raises `ShioajiValueError` if the
leg count is wrong (matches the sw backend hard requirement at
`swrelaystation/api/v1/endpoints/order/place_comboorder.py:67-68`).

### Create Combo Contract — field-by-field 建立組合合約

```python
import shioaji as sj

# Futures calendar spread — buy near-month, sell next-month
combo_contract = sj.ComboContract(
    legs=[
        sj.ComboBase(
            action=sj.Action.Buy,
            security_type=sj.SecurityType.Future,
            exchange=sj.Exchange.TAIFEX,
            code="TXFG5",
            symbol="TXFG5",
            category="TXF",
            delivery_month="202607",
        ),
        sj.ComboBase(
            action=sj.Action.Sell,
            security_type=sj.SecurityType.Future,
            exchange=sj.Exchange.TAIFEX,
            code="TXFH5",
            symbol="TXFH5",
            category="TXF",
            delivery_month="202608",
        ),
    ]
)
```

### Create Combo Contract — from richer contract objects (compat helper)

Canonical shioaji users can pass a full `Contract` / `Future` / `Option` /
`Stock` / `Index` and let shioaji extract the relevant fields:

```python
r1 = api.Contracts.Futures["TXFR1"]   # near-month alias
r2 = api.Contracts.Futures["TXFR2"]   # next-month alias

combo_contract = sj.ComboContract(legs=[
    sj.ComboBase.from_contract(r1, action=sj.Action.Buy),
    sj.ComboBase.from_contract(r2, action=sj.Action.Sell),
])
```

`from_contract` copies `security_type/exchange/code/symbol/category/
delivery_month/strike_price/option_right/target_code`. For bare
`BaseContract` instances (only 4 fields) use the field-by-field constructor.

### Place Combo Order 下組合單

```python
# Canonical shape: ComboOrder defaults action=Sell (see note below).
# Legs built via ComboBase.from_contract(future_or_option) carry full
# contract info — shioaji auto-fills `combo_type` for you, so you can
# omit it.
order = sj.ComboOrder(
    price=50,   # Net price 淨價
    quantity=1,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_comboorder(combo_contract, order)
```

`place_comboorder` also accepts a plain `FuturesOrder` for backcompat —
the same auto-fill path runs when the legs are full contracts.

#### `combo_type` — when to fill it yourself 何時需要自己帶入

- **Full contracts** (`ComboBase.from_contract(future_or_option)` or
  manually populating `category` / `delivery_month` / `strike_price` /
  `option_right`): shioaji auto-fills `combo_type` from the leg shape.
  You can omit the argument.
- **Bare `BaseContract` legs** (only `security_type` / `exchange` /
  `code`): Shioaji cannot infer the strategy. **You must pass
  `combo_type=sj.ComboType.<variant>` yourself**, otherwise
  `place_comboorder` raises `ShioajiValueError`.
- **`WeeklyTimeSpread`**: always pass it explicitly — the auto-fill path
  can't tell it apart from `TimeSpread` (they share `f_mttype` "2").
- **Explicit always wins**: passing `combo_type=...` overrides the
  auto-fill regardless of leg shape.

| `sj.ComboType.*`     | f_mttype | Strategy                         |
| -------------------- | :------: | -------------------------------- |
| `PriceSpread`        | `1`      | 價格價差                          |
| `TimeSpread`         | `2`      | 時間價差 (跨月價差)                 |
| `Straddle`           | `3`      | 跨式                             |
| `Strangle`           | `4`      | 勒式                             |
| `ConversionReversal` | `5`      | 轉換 / 逆轉組合                    |
| `WeeklyTimeSpread`   | `2`      | 週選跨月價差                       |

```python
order = sj.ComboOrder(
    price=50,
    quantity=1,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    combo_type=sj.ComboType.WeeklyTimeSpread,
)
```

#### Note on combo-level `action`

`ComboOrder.action` defaults to `Sell` to match canonical `shioaji.ComboOrder`
(`shioaji/order.py:105-128`). **Per-leg `ComboBase.action` is what the
exchange reads for combo direction** (mapped to STS `ord_bs` and `c_buysell`).
The order-level `action` reaches the wire as `trade_type` (see
`swrelaystation/backend/sts/protocol/futureoption/handler.py:219` and the
binary struct at `tr.py:5-44`), but its semantic effect on TAIFEX matching
for combo orders is empirically unverified — the sw author's comment
`# trade_type如果sell會不會有影響` ("does Sell have any effect?") reflects
this open question. The canonical default of `Sell` is used here to
minimise divergence from `shioaji`; if you need a specific value, pass
`action=...` explicitly.

#### HTTP: Place Combo Order

```bash
# POST /api/v1/order/place_comboorder
curl -X POST http://localhost:8080/api/v1/order/place_comboorder \
  -H "Content-Type: application/json" \
  -d '{
    "combo_contract": {
      "legs": [
        {"action": "Buy",  "security_type": "FUT", "exchange": "TAIFEX", "code": "TXFG5", "symbol": "TXFG5", "category": "TXF", "delivery_month": "202607"},
        {"action": "Sell", "security_type": "FUT", "exchange": "TAIFEX", "code": "TXFH5", "symbol": "TXFH5", "category": "TXF", "delivery_month": "202608"}
      ]
    },
    "order": {
      "action": "Sell",
      "price": 50,
      "quantity": 1,
      "price_type": "LMT",
      "order_type": "ROD",
      "octype": "Auto",
      "combo_type": "Straddle"
    }
  }'
```

`combo_type` is optional on the JSON body when each leg includes the
full contract fields (`category`, `delivery_month`, and for options
`strike_price` / `option_right`); shioaji auto-fills it on the server
side. Pass it explicitly when the legs are bare codes, or when you need
`WeeklyTimeSpread`. Accepted values: `PriceSpread`, `TimeSpread`,
`Straddle`, `Strangle`, `ConversionReversal`, `WeeklyTimeSpread`.

Note on payload keys: the public shioaji HTTP request body uses
`combo_contract`. Do not send `combocontract` to shioaji's HTTP server.

### Cancel Combo Order 取消組合單

```python
api.cancel_comboorder(trade)
```

#### HTTP: Cancel Combo Order

```bash
# POST /api/v1/order/cancel_comboorder
curl -X POST http://localhost:8080/api/v1/order/cancel_comboorder \
  -H "Content-Type: application/json" \
  -d '{"trade_id": "abc123"}'
```

### Combo Trades 組合單查詢

```python
# Update combo status 更新組合單狀態
api.update_combostatus(api.futopt_account)

# List all combo trades 列出所有組合單
combo_trades = api.list_combotrades()
```

#### HTTP: List Combo Trades

```bash
# POST /api/v1/order/combotrades
curl -X POST http://localhost:8080/api/v1/order/combotrades \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Modify Orders 改單

For HTTP/JS/Go/Rust/C#/Java clients, update/cancel endpoints do **not** accept a full Python `Trade` object. They accept `trade_id`, which is the nested `Trade.order.id` from the server's trade cache. If the order was not just placed by the same running server, or if the client only knows `ordno`/`seqno`, first call `POST /api/v1/order/trades` with the account. That endpoint runs `update_status(account)`, refreshes the server cache, and returns `Vec<Trade>`. Select the intended trade, then send `trade.order.id`.
HTTP/JS/Go/Rust/C#/Java client 的改單/刪單 endpoint 不吃 Python 的完整 `Trade` 物件，而是吃 `trade_id`，也就是 server trade cache 裡的 `Trade.order.id`。如果該委託不是剛由同一個 running server 下出，或 client 只知道 `ordno`/`seqno`，要先用帳號呼叫 `POST /api/v1/order/trades`。這個 endpoint 會先執行 `update_status(account)`、刷新 server cache、回傳 `Vec<Trade>`；選到目標 trade 後，再送 `trade.order.id`。

Do not use a deal-event `trade_id` blindly unless you know it matches the same `Trade.order.id`. The safer HTTP flow is: `/order/trades` -> pick `trade.order.id` -> `/order/update_price`, `/order/update_qty`, or `/order/cancel_order` -> wait for `order_deal_event` or call `/order/trades` again to confirm.
不要盲目使用成交回報裡的 `trade_id`，除非已確認它和同一筆委託的 `Trade.order.id` 對得上。HTTP 較安全流程是：`/order/trades` -> 選 `trade.order.id` -> `/order/update_price`、`/order/update_qty` 或 `/order/cancel_order` -> 等 `order_deal_event` 或再呼叫 `/order/trades` 確認。

### Change Price 改價

```python
api.update_order(trade=trade, price=585)
```

#### HTTP: Update Price

```bash
# First refresh/list trades and copy the target trade.order.id.
curl -X POST http://localhost:8080/api/v1/order/trades \
  -H "Content-Type: application/json" \
  -d '{"account_type":"S"}'

# POST /api/v1/order/update_price
curl -X POST http://localhost:8080/api/v1/order/update_price \
  -H "Content-Type: application/json" \
  -d '{"trade_id": "abc123", "price": 585}'
```

### Reduce Quantity 減量

Note: Can only reduce, not increase.
注意：只能減少，不能增加。

```python
api.update_order(trade=trade, qty=1)
```

#### HTTP: Update Quantity

```bash
# First refresh/list trades and copy the target trade.order.id.
curl -X POST http://localhost:8080/api/v1/order/trades \
  -H "Content-Type: application/json" \
  -d '{"account_type":"S"}'

# POST /api/v1/order/update_qty
curl -X POST http://localhost:8080/api/v1/order/update_qty \
  -H "Content-Type: application/json" \
  -d '{"trade_id": "abc123", "quantity": 1}'
```

---

## Cancel Orders 刪單

```python
api.cancel_order(trade)
```

#### HTTP: Cancel Order

```bash
# First refresh/list trades and copy the target trade.order.id.
curl -X POST http://localhost:8080/api/v1/order/trades \
  -H "Content-Type: application/json" \
  -d '{"account_type":"S"}'

# POST /api/v1/order/cancel_order
curl -X POST http://localhost:8080/api/v1/order/cancel_order \
  -H "Content-Type: application/json" \
  -d '{"trade_id": "abc123"}'
```

---

## Order Status 訂單狀態

### Order Response and Decision Summary 委託回應與決策摘要

Use this table when deciding the next step after an order API call. Do not infer final exchange state from HTTP 200, CLI command success, or the first Python `Trade` object alone.

| Operation | Python return | HTTP response | CLI output | Agent decision |
|---|---|---|---|---|
| Place stock/futures/options order | `Trade` | `Trade` JSON | `shioaji order place --format json` returns `Trade` JSON; default output may be formatted | Inspect `trade.status.status`. If it is `PendingSubmit`, wait for `order_deal_event` first; use `update_status()` / `/api/v1/order/trades` only for reconciliation, missed events, or offline recovery. |
| Cancel order | `Trade` | `Trade` JSON | `shioaji order cancel --format json` returns `Trade` JSON; default output may be formatted | HTTP/JS/Go/Rust/C#/Java body uses `trade_id = Trade.order.id`. Returned `Trade` may not be the final cancelled state; confirm with `order_deal_event` or refreshed trades. |
| Update price | `Trade` | `Trade` JSON | `shioaji order update-price --format json` returns `Trade` JSON; default output may be formatted | Same `trade_id = Trade.order.id` cache rule as cancel. Confirm final state by active order/deal report or refreshed trades. |
| Update quantity | `Trade` | `Trade` JSON | `shioaji order update-qty --format json` returns `Trade` JSON; default output may be formatted | Same cache rule as update price. Quantity can only be reduced; intraday odd lot can reduce quantity but cannot update price. |
| List trades / update status | Python `List[Trade]`; sync `api.update_status(..., cb=...)` returns `None` when callback is used | `Vec<Trade>` JSON | `shioaji order list --format json` returns `Vec<Trade>` JSON; default output may be formatted | Empty list can be normal when there are no active/recent trades or the wrong account was selected. Do not treat empty as API failure without checking account and context. |
| Place combo order | `ComboTrade` | `ComboTrade` JSON | No primary CLI command; use Python or HTTP | Two legs are required. Response is combo trade state, not a plain `Trade`; use combo status/list for confirmation. |
| Cancel combo order | `ComboTrade` | `ComboTrade` JSON | No primary CLI command; use Python or HTTP | Same status-read pattern as combo order. |
| List combo trades | `List[ComboTrade]` | `Vec<ComboTrade>` JSON | No primary CLI command; use Python or HTTP | Empty list can mean no combo orders exist for that account/session. |
| Order/deal records | `List[tuple[OrderState, dict]]` | `Vec<OrderEventData>` JSON | Use `shioaji order events` for active SSE, not historical records | Historical/reconciliation query only; not active streaming. In simulation it returns empty. |

HTTP `Trade` responses are nested JSON objects. For HTTP and other-language clients:

- Read order id from `trade.order.id`; do not expect a top-level `order_id`.
- Read current state from `trade.status.status`.
- `trade.status` wire fields can include raw timestamps such as `order_ts` and `modified_ts`; Python `trade.status.dict()` exposes converted values such as `order_datetime` and `modified_time`.
- Do not infer filled/cancelled from successful HTTP status alone.

Python `update_status` behavior:

- Sync `api.update_status(..., cb=...)` returns `None`; the callback receives `List[Trade]`.
- Async `await api.update_status(...)` returns `List[Trade]`.

### Update Status 更新狀態

```python
# Update all order status 更新所有訂單狀態
api.update_status(api.stock_account)
api.update_status(api.futopt_account)

# Update specific trade only 僅更新特定訂單
api.update_status(trade=trade)
```

### List Trades 列出交易

```python
# List all trades from cache 從快取列出所有交易
trades = api.list_trades()

for trade in trades:
    print(f"Order: {trade.order.id}")
    print(f"Status: {trade.status.status}")
    print(f"Deal Quantity: {trade.status.deal_quantity}")
```

#### HTTP: Get Trades

```bash
# POST /api/v1/order/trades
curl -X POST http://localhost:8080/api/v1/order/trades \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Trade Status Values 交易狀態值

`PendingSubmit` is a normal intermediate response from order APIs. Do not tell users the order was submitted, failed, filled, or cancelled until active reports (Python callback / HTTP SSE) or a reconciliation `update_status()` confirms the later state.
`PendingSubmit` 是下單 API 可能回傳的正常中間狀態。不要在主動回報（Python callback / HTTP SSE）或補查用的 `update_status()` 確認後續狀態前，告訴使用者該單已送出、失敗、成交或取消。

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

These attributes describe Python `Trade` objects returned by `api.place_order()` / `api.list_trades()`. HTTP `Trade` responses are nested server JSON objects: read `trade.order.id`, `trade.status.status`, and fill records from `trade.status.deals`; fetch `/openapi.json` only when exact installed-server field typing is required.
以下是 Python `api.place_order()` / `api.list_trades()` 回傳的 `Trade` 物件屬性。HTTP `Trade` response 是巢狀 server JSON 物件：請從巢狀物件讀 `trade.order.id`、`trade.status.status`，成交明細讀 `trade.status.deals`；只有需要確認安裝版本精確欄位型別時才查 `/openapi.json`。

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

## Order Deal Records 委託成交紀錄

Retrieve today's order and deal records as a list of `(OrderState, dict)` tuples.
取得今日委託及成交紀錄，回傳 `(OrderState, dict)` 元組列表。

```python
records = api.order_deal_records()

for state, event in records:
    print(f"State: {state}, Event: {event}")
```

#### HTTP: Order Deal Records

```bash
# POST /api/v1/order/order_deal_records
curl -X POST http://localhost:8080/api/v1/order/order_deal_records \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Note 注意:** Not available in simulation mode. Returns empty list when `simulation=True`.
模擬模式下不可用，`simulation=True` 時回傳空列表。

---

## Order Deal Event 主動委託/成交回報

Shioaji names this feature `order_deal_event`: active order/deal events pushed after `place_order`, `update_order`, or `cancel_order`. In Python, receive it with `set_order_callback` / `@api.on_order`; in HTTP/server clients, receive the same event family through `/api/v1/stream/data/order_event` SSE. Do not confuse this with `order_deal_records`, which is a historical/reconciliation query.
Shioaji 將這個功能稱為 `order_deal_event`：在 `place_order`、`update_order` 或 `cancel_order` 後由交易所主動推送的委託/成交回報。Python 用 `set_order_callback` / `@api.on_order` 接；HTTP/server client 透過 `/api/v1/stream/data/order_event` SSE 接同一類事件。不要和 `order_deal_records` 混淆，後者是歷史/對帳查詢。

### Event Variants and Payloads 回報種類與 payload

| Event state | Meaning | Python callback payload | HTTP SSE payload |
|-------------|---------|-------------------------|------------------|
| `OrderState.StockOrder` / `SORDER` | Stock order accepted/updated/cancelled | dict-like event with `operation`, `order`, `status`, `contract` | `{"state":"StockOrder","data":{"StockOrder":{...}}}` |
| `OrderState.StockDeal` / `SDEAL` | Stock deal / partial fill / fill | dict-like event with `trade_id`, `seqno`, `ordno`, `exchange_seq`, `broker_id`, `account_id`, `action`, `code`, `order_cond`, `order_lot`, `price`, `quantity`, `web_id`, `custom_field`, `ts` | `{"state":"StockDeal","data":{"StockDeal":{...}}}` |
| `OrderState.FuturesOrder` / `FORDER` | Futures/options order accepted/updated/cancelled | dict-like event with `operation`, `order`, `status`, `contract` | `{"state":"FuturesOrder","data":{"FuturesOrder":{...}}}` |
| `OrderState.FuturesDeal` / `FDEAL` | Futures/options deal / partial fill / fill | dict-like event with `trade_id`, `seqno`, `ordno`, `exchange_seq`, `broker_id`, `account_id`, `action`, `code`, `price`, `quantity`, `subaccount`, `security_type`, `delivery_month`, `full_code`, `strike_price`, `option_right`, `market_type`, `combo`, `ts` | `{"state":"FuturesDeal","data":{"FuturesDeal":{...}}}` |

Agent decision rules:

- Match order and deal events with `order.id` / `status.id` to deal `trade_id`.
- Deal events may arrive before order events because exchange message priority can favor deals.
- `operation.op_code == "00"` means the order operation succeeded; other values mean failure and `operation.op_msg` should be surfaced.
- When `place_order()` returns `PendingSubmit`, do not guess final state. Wait for `order_deal_event` first; use `update_status()` or `order_deal_records()` only for reconciliation, missed events, or offline recovery.

---

## Order Callback API 訂單回報 API

Order and deal events are pushed automatically when orders are submitted or filled.
委託及成交事件會在下單或成交時主動推送。

### set_order_callback 設定委託回報

```python
def order_cb(stat, msg):
    print(f"State: {stat}")
    print(f"Message: {msg}")

api.set_order_callback(order_cb)
```

### clear_order_callback 清除委託回報

```python
api.clear_order_callback()
```

### set_event_callback 設定事件回報

```python
def event_cb(resp_code: int, event_code: int, info: str, event: str):
    print(f"Event: {event_code} - {event}")

api.set_event_callback(event_cb)
```

### clear_event_callback 清除事件回報

```python
api.clear_event_callback()
```

### Async Callbacks 非同步回報

For `ShioajiAsync`, callbacks must be async functions:
對於 `ShioajiAsync`，回調必須是非同步函式：

```python
api = sj.ShioajiAsync()
await api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

async def order_cb(stat, msg):
    print(f"State: {stat}, Message: {msg}")

api.set_order_callback(order_cb)

async def event_cb(resp_code: int, event_code: int, info: str, event: str):
    print(f"Event: {event_code} - {event}")

api.set_event_callback(event_cb)
```

### Decorator Syntax 裝飾器語法

```python
@api.on_order
def order_cb(stat, msg):
    print(f"State: {stat}, Message: {msg}")

@api.on_event
def event_cb(resp_code: int, event_code: int, info: str, event: str):
    print(f"Event: {event_code} - {event}")
```

### OrderState Types 回報狀態類型

```python
import shioaji as sj

sj.OrderState.StockOrder  # 股票委託回報
sj.OrderState.StockDeal   # 股票成交回報
sj.OrderState.FuturesOrder  # 期貨委託回報
sj.OrderState.FuturesDeal   # 期貨成交回報
```

### Handle Different Events 處理不同事件

Split handlers by event type for clear type hints:
依事件類型拆分 handler 以獲得明確的型別提示：

```python
from shioaji import OrderState

def order_cb(stat, msg):
    if stat == OrderState.StockOrder:
        op = msg["operation"]
        if op["op_code"] == "00":
            print(f"Stock order {op['op_type']} success: {msg['order']['id']}")
        else:
            print(f"Stock order failed: {op['op_msg']}")
    elif stat == OrderState.StockDeal:
        print(f"Stock deal: {msg['code']} @ {msg['price']} x {msg['quantity']}")
    elif stat == OrderState.FuturesOrder:
        print(f"Futures order: {msg['order']['action']} {msg['contract']['code']}")
    elif stat == OrderState.FuturesDeal:
        print(f"Futures deal: {msg['code']} @ {msg['price']} x {msg['quantity']}")

api.set_order_callback(order_cb)
```

**Note 注意:** Deal events may arrive before order events due to exchange message priority.
成交回報可能比委託回報更早到達，因為交易所訊息優先順序不同。

### HTTP: Order Events via SSE

Order events are available through SSE streaming. See [STREAMING.md](STREAMING.md) for SSE details.
委託事件可透過 SSE 串流取得，詳見 [STREAMING.md](STREAMING.md)。

---

## Subscribe/Unsubscribe Trade 訂閱/取消訂閱交易回報

Subscribe to trade events for a specific account. **Required** before consuming the order_event SSE stream in production — without it the relay does not forward FORDER/FDEAL/SORDER/SDEAL to the client. Same explicit-subscribe pattern as market-data subscription (#237).

訂閱特定帳戶的交易事件，啟用即時委託/成交通知。正式環境下消費 `/stream/data/order_event` SSE 之前**必須**呼叫一次（每帳號一次），否則 relay 不會推送回報；pattern 與訂閱報價一致。

### Python

```python
# Subscribe 訂閱
result = api.subscribe_trade(api.stock_account)
print(f"Subscribed: {result}")  # True if successful

# Unsubscribe 取消訂閱
result = api.unsubscribe_trade(api.stock_account)
print(f"Unsubscribed: {result}")
```

#### Async 非同步

```python
result = await api.subscribe_trade(api.stock_account)
result = await api.unsubscribe_trade(api.stock_account)
```

### HTTP (shioaji server)

```bash
# Subscribe — required before opening /stream/data/order_event
curl -X POST http://localhost:8080/api/v1/auth/subscribe_trade \
  -H "Content-Type: application/json" \
  -d '{"broker_id":"9A95","account_id":"1234567","account_type":"S"}'

# Unsubscribe
curl -X POST http://localhost:8080/api/v1/auth/unsubscribe_trade \
  -H "Content-Type: application/json" \
  -d '{"broker_id":"9A95","account_id":"1234567","account_type":"S"}'
```

Body shape: `{broker_id, account_id, account_type}` (`S` for stock, `F` for futures/options). Omit `broker_id`/`account_id` to subscribe the default account of `account_type`.

Subscriptions survive the server's daily client refresh, so callers only need to subscribe once per server boot per account. See [STREAMING.md](STREAMING.md) and [HTTP_API.md](HTTP_API.md#post-apiv1authsubscribe_trade) for full SSE/endpoint reference.

---

## Best Practices 最佳實踐

### 1. Use Callbacks for Real-time Status 使用主動回報獲取即時狀態

Prefer callbacks over `update_status()` to avoid rate limits.
優先使用主動回報而非 `update_status()` 以避免觸發流量限制。

### 2. Non-blocking Orders 非阻塞下單

Pass `timeout=0` for fire-and-forget order placement with optional callback:
傳入 `timeout=0` 進行非阻塞下單，可附帶回調：

```python
def on_order_done(trade):
    print(f"Order result: {trade.order.id} - {trade.status.status}")

trade = api.place_order(contract, order, timeout=0, cb=on_order_done)
# Returns immediately with placeholder trade
# 立即回傳佔位 trade 物件
```

### 3. Use update_status Only When Needed 僅在必要時使用 update_status

Only use `update_status()` for:
僅在以下情況使用 `update_status()`：

- After reconnection 斷線重連後
- Query historical orders 查詢歷史訂單
- When callback missed 回報遺漏時

### 4. Handle Errors Gracefully 優雅處理錯誤

```python
try:
    trade = api.place_order(contract, order)
except Exception as e:
    print(f"Order error: {e}")
```

For CLI order commands, see [CLI.md](CLI.md).
CLI 下單命令請參見 [CLI.md](CLI.md)。

For full HTTP endpoint inventory, see [HTTP_API.md](HTTP_API.md).
完整的 HTTP 端點清單請參見 [HTTP_API.md](HTTP_API.md)。
