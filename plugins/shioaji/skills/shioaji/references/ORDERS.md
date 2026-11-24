# Orders 下單

This document covers placing, modifying, and canceling orders in Shioaji.
本文件說明如何在 Shioaji 中下單、改單和刪單。

Use [MIGRATION.md](MIGRATION.md) when migrating legacy order constructors or
submodule constants. This file owns regular `Trade`, `Vec<Trade>`,
`PendingSubmit`, and order-event response decisions. Combo-order-specific
rules and `ComboTrade` status handling live in
[COMBO_ORDERS.md](COMBO_ORDERS.md).

## Table of Contents 目錄

- [Prerequisites 前置條件](#prerequisites-前置條件)
- [Stock Orders 股票下單](#stock-orders-股票下單)
- [Futures Orders 期貨下單](#futures-orders-期貨下單)
- [Options Orders 選擇權下單](#options-orders-選擇權下單)
- [US Stock Orders 美股下單](#us-stock-orders-美股下單)
- [Combo Orders 組合單](#combo-orders-組合單)
- [Modify Orders 改單](#modify-orders-改單)
- [Cancel Orders 刪單](#cancel-orders-刪單)
- [Order Status 訂單狀態](#order-status-訂單狀態)
- [Order Deal Records 委託成交紀錄](#order-deal-records-委託成交紀錄)
- [Order Deal Event 主動委託/成交回報](#order-deal-event-主動委託成交回報)
- [Order Callback API 訂單回報 API](#order-callback-api-訂單回報-api)
- [Subscribe/Unsubscribe Trade 訂閱/取消訂閱交易回報](#subscribeunsubscribe-trade-訂閱取消訂閱交易回報)
- [Best Practices 最佳實踐](#best-practices-最佳實踐)

---

## Prerequisites 前置條件

Before placing **production** orders, ensure CA is activated. Simulation orders skip CA signing automatically.
正式環境下單前請確認已啟用憑證；模擬下單會自動跳過 CA 簽章。

For HTTP orders, first inspect `/api/v1/info`. If
`agent_harness.enabled=true`, follow
[AGENT_HARNESS.md](AGENT_HARNESS.md) before place/update/cancel: serialize the
body once, obtain approval from the trusted native broker, and send those exact
bytes with its one-time capability. Capability acceptance does not replace the
order-status reconciliation described below.

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

Python order examples below assume login is complete. Resolve a Base contract through `api.contracts.get()` and pass that Base directly to `place_order()`; Info is needed only when pricing/risk logic reads fields such as reference prices or limits. Contract V2 loads the required data lazily. Choose simulation/production intentionally, activate CA for production orders, and always inspect `trade.status.status` after `place_order()`.
以下 Python 下單範例假設已完成登入。請透過 `api.contracts.get()` 取得 Base contract，並直接傳給 `place_order()`；只有定價或風控需要參考價、漲跌停等欄位時才查 Info。Contract V2 會按需載入所需資料。請明確選擇 simulation/production，正式下單前啟用 CA，並在 `place_order()` 後檢查 `trade.status.status`。

`place_order()` returns a `Trade`, but the first returned status can be `PendingSubmit` (`傳送中`). Treat `PendingSubmit` as an intermediate state, not a final exchange acknowledgement. To know whether the order became `Submitted`, `Filled`, `PartFilled`, `Failed`, or `Cancelled`, prefer waiting for active order/deal reports first: Python order callbacks or HTTP order-event SSE. Use `api.update_status(trade=trade)` / `api.update_status(account)` when callbacks/SSE are unavailable, were missed, or a reconciliation check is needed.
`place_order()` 會回 `Trade`，但第一次回來的狀態可能是 `PendingSubmit`（傳送中）。請把 `PendingSubmit` 視為中間狀態，不是交易所最終確認。若要知道是否變成 `Submitted`、`Filled`、`PartFilled`、`Failed` 或 `Cancelled`，優先等待主動委託/成交回報：Python order callback 或 HTTP order-event SSE。只有在無法使用 callback/SSE、疑似漏回報或需要對帳補查時，才用 `api.update_status(trade=trade)` / `api.update_status(account)`。

Since 1.7.6, active reports are projected into the Trade cache before they are delivered to callbacks or SSE. When your callback runs, `api.list_trades()` and any `Trade` you already hold already reflect that report; no `update_status()` call is needed to observe it.
1.7.6 起，主動回報會先投影進 Trade cache，才交付給 callback／SSE。因此 callback 被呼叫的當下，`api.list_trades()` 與你已持有的 `Trade` 物件就已經反映該筆回報，不需要再呼叫 `update_status()`。

### Basic Stock Order 基本股票下單

```python
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")

order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    order_lot=sj.StockOrderLot.Common,
    account=api.stock_account,
)

trade = api.place_order(contract, order)
print(trade.status.status)  # May be PendingSubmit 可能是 PendingSubmit

# `trade` is a live view (1.7.6+): read it again after the active report arrives
# (for example inside the order callback) to see the new state.
# `trade` 是 live view（1.7.6+）：主動回報到達後（例如在 order callback 內）再讀一次就是新狀態。
# Use api.update_status(trade=trade) only when callbacks/SSE are unavailable
# or a report may have been missed.
# 只有在無法使用 callback/SSE 或疑似漏回報時，才用 api.update_status(trade=trade)。
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
      "time_in_force": "ROD",
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
| `price_type` | StockPriceType | LMT/MKT 限價/市價 |
| `time_in_force` | TimeInForce | ROD/IOC/FOK 委託條件 (legacy name 舊名 `order_type` still accepted 仍可用) |
| `order_lot` | OrderLot | Common/Odd/IntradayOdd/Fixing 交易單位 |
| `order_cond` | OrderCond | Cash/MarginTrading/ShortSelling/SBLShort/SBLShortPriceExempt 信用條件 |
| `account` | Account | Trading account 交易帳戶 |
| `custom_field` | str | Memo (max 6 chars) 備註（最多6字元）|

> **`time_in_force` vs `order_type`**: since 1.7.9 the ROD/IOC/FOK field is officially named `time_in_force` (international usage; "order type" usually means the price type). `order_type` is the old name and stays accepted permanently: Python constructors take `order_type=`, HTTP bodies take `"order_type"`, and returned orders/trades/order events carry both `time_in_force` and `order_type` with the same value. Passing both with different values is rejected (ValueError / HTTP 400). The `time_in_force` field uses the `sj.TimeInForce` enum and the legacy `order_type` field keeps returning `sj.OrderType`; the two enums have the same values, compare equal (also to the plain string, e.g. `== "ROD"`), and either is accepted by either argument.
> **`time_in_force` 與 `order_type`**：1.7.9 起 ROD/IOC/FOK 欄位正式名稱為 `time_in_force`（國際慣例中 order type 指的是價格類型）。`order_type` 為舊名稱，永久保留可用：Python 建構子可傳 `order_type=`、HTTP body 可帶 `"order_type"`，回傳的委託、Trade 與委託回報會同時帶 `time_in_force` 和 `order_type`（值相同）。兩者同時給且值不同會被拒絕（ValueError / HTTP 400）。`time_in_force` 欄位用 `sj.TimeInForce` 列舉，舊的 `order_type` 欄位照舊回傳 `sj.OrderType`；兩個列舉的值相同、彼此相等（和字串比較如 `== "ROD"` 也相等），兩個參數都可以收任一種。

#### Time in force 委託條件

`time_in_force` says how long an order stays on the exchange book and whether it may fill partly. Default: `ROD`.
`time_in_force` 決定委託在交易所掛多久、能不能部分成交。預設 `ROD`。

| Value 值 | Meaning | 說明 | Typical use 常見用途 |
|---|---|---|---|
| `ROD` | Rest of Day: stays on the book until it fills, is cancelled, or the session ends. Partial fills are kept and the rest keeps waiting. | 當日有效：掛到成交、被刪單或收盤為止；部分成交後剩餘數量繼續掛著。 | Normal limit orders 一般限價掛單 |
| `IOC` | Immediate or Cancel: fills whatever it can right away; the unfilled rest is cancelled at once. | 立即成交否則取消：能成交多少就成交多少，沒成交的部分立刻取消。 | Take available liquidity now, accept a partial fill 吃現有掛單、接受部分成交 |
| `FOK` | Fill or Kill: fills the whole quantity right away, or nothing fills and the whole order is cancelled. | 全部成交否則取消：必須立即全部成交，否則整筆取消、一口也不成交。 | All-or-nothing entry 要嘛全成、要嘛不做 |

How to set it 怎麼帶：

```python
sj.StockOrder(..., price_type=sj.StockPriceType.LMT, time_in_force=sj.TimeInForce.IOC, ...)
sj.StockOrder(..., time_in_force="IOC", ...)   # string also accepted 也可傳字串
sj.StockOrder(..., order_type="IOC", ...)      # legacy name, same effect 舊名稱，效果相同
```

```bash
# HTTP body
{"time_in_force": "IOC"}        # or legacy 或舊名稱 {"order_type": "IOC"}
# CLI
shioaji order place ... --tif ioc   # also --time-in-force; legacy --order-type 仍可用
```

- An `IOC`/`FOK` order that does not fill is reported as cancelled right away; that is normal, not an error. Check `deal_quantity` / `status` to see what filled.
  `IOC`／`FOK` 沒成交時會立刻收到取消，這是正常結果不是錯誤；用 `deal_quantity`／`status` 看實際成交多少。
- Which combinations an exchange accepts differs by market: see the stock table below and [Futures Parameters](#futures-parameters-期貨參數) (TAIFEX rejects `MKT`/`MKP` + `ROD`; standard option combos reject `ROD`).
  各市場可接受的組合不同：見下方股票表格與[期貨參數](#futures-parameters-期貨參數)（期交所拒絕 `MKT`／`MKP` + `ROD`；選擇權標準組合單不接受 `ROD`）。

**Stocks (TWSE / TPEx)** — stock `price_type` is only MKT/LMT. Stocks have no MKP: in Python, passing it raises `ShioajiValueError: Invalid StockPriceType: MKP`. Which combinations the exchange accepts depends on the session and the lot type. This differs from TAIFEX; see [Futures Parameters](#futures-parameters-期貨參數).
**上市、上櫃股票** — 股票 `price_type` 只有 MKT/LMT。股票沒有 MKP，Python 帶入會丟 `ShioajiValueError: Invalid StockPriceType: MKP`。交易所接受哪些組合，依時段與交易單位而定；與期交所限制不同。

| Session / lot 時段／交易單位 | Accepted 可用組合 |
|---|---|
| `Common`, continuous trading 整股逐筆交易（09:00–13:25） | MKT/LMT × ROD/IOC/FOK |
| `Common`, call auction 整股集合競價（盤前 08:30–09:00、收盤 13:25–13:30、價格穩定措施期間） | LMT + ROD only 僅限價 ROD |
| `IntradayOdd` / `Odd` / `Fixing` 盤中零股／盤後零股／盤後定價 | LMT + ROD only 僅限價 ROD |

### Market Order 市價單

```python
order = sj.StockOrder(
    price=0,  # Price ignored for MKT 市價單忽略價格
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.MKT,
    time_in_force=sj.TimeInForce.ROD,
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
    time_in_force=sj.TimeInForce.ROD,
    order_lot=sj.StockOrderLot.IntradayOdd,
    account=api.stock_account,
)

# After-hours odd lot 盤後零股 (13:40-14:30)
order = sj.StockOrder(
    price=580,
    quantity=100,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    order_lot=sj.StockOrderLot.Odd,
    account=api.stock_account,
)
```

**Note 注意:** IntradayOdd orders cannot update price, only reduce quantity.
盤中零股委託不能改價，只能減量。

### Margin, Short Selling, and Securities Borrowing 融資、融券與借券

```python
# Margin buy 融資買進
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    order_cond=sj.StockOrderCond.MarginTrading,
    account=api.stock_account,
)

# Short sell 融券賣出
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    order_cond=sj.StockOrderCond.ShortSelling,
    account=api.stock_account,
)

# Securities borrowing sell 借券賣出
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    order_cond=sj.StockOrderCond.SBLShort,
    account=api.stock_account,
)

# Price-exempt securities borrowing sell 價格豁免借券賣出
exempt_order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    order_cond=sj.StockOrderCond.SBLShortPriceExempt,
    account=api.stock_account,
)
```

`SBLShort` is order type 5 (general strategic securities-borrowing and
lending short sale). `SBLShortPriceExempt` is order type 6 (price-exempt
SBL short sale for eligible special financial products). Both are distinct
from `ShortSelling`, which means a margin short sale (融券賣出), and from the
quote field `avail_borrowing` (available shares to borrow). Use them with
`Action.Sell`; account eligibility, borrow position, product eligibility, and
order validity are confirmed by the backend/exchange.

`SBLShort` 是委託類別 5（一般策略性借券賣出）；
`SBLShortPriceExempt` 是委託類別 6（適用特殊金融商品的價格豁免
借券賣出）。兩者都不同於 `ShortSelling`（融券賣出），也不是行情欄位
`avail_borrowing`（可借券數量）。請搭配 `Action.Sell`；帳戶資格、借券
部位、商品資格與委託是否合法由後端／交易所確認。

### Day Trading 現股當沖

`daytrade_short=True` means **sell first, buy back later** (先賣後買). Set it only on the
opening **sell**; never set it on a buy.
`daytrade_short=True` 代表**先賣後買**，只在開倉的**賣單**設定，買單不要設。

```python
# Sell first (open) 先賣（現股當沖賣出）
order = sj.StockOrder(
    price=590,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    daytrade_short=True,  # sell-then-buy day trade 先賣後買
    account=api.stock_account,
)

# Buy back the same day (close) 當日買回（一般買單）
order = sj.StockOrder(
    price=580,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    account=api.stock_account,
)
```

Buy-first day trading (先買後賣) uses ordinary cash orders for both legs, without
`daytrade_short`. Whether selling shares bought today is accepted depends on the
account's day-trading eligibility, which the broker checks.
先買後賣兩筆都用一般現股單，不帶 `daytrade_short`；能否賣出今日買進的股數由帳戶當沖資格決定，券商端檢查。

---

## Futures Orders 期貨下單

### Basic Futures Order 基本期貨下單

```python
contract = api.contracts.get("TXFR1")  # Continuous near month 連續近月
if contract is None:
    raise LookupError("contract TXFR1 not found")

order = sj.FuturesOrder(
    price=18000,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.FuturesPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    octype=sj.FuturesOCType.Auto,  # Auto open/close 自動開平
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
print(trade.status.status)  # May be PendingSubmit 可能是 PendingSubmit

# `trade` is a live view (1.7.6+): read it again after the active report arrives
# (for example inside the order callback) to see the new state.
# `trade` 是 live view（1.7.6+）：主動回報到達後（例如在 order callback 內）再讀一次就是新狀態。
# Use api.update_status(trade=trade) only when callbacks/SSE are unavailable
# or a report may have been missed.
# 只有在無法使用 callback/SSE 或疑似漏回報時，才用 api.update_status(trade=trade)。
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
      "time_in_force": "ROD",
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
| `time_in_force` | TimeInForce | ROD/IOC/FOK 委託條件 (legacy name 舊名 `order_type` still accepted 仍可用) |
| `octype` | FuturesOCType | Auto/New/Cover/DayTrade 自動/新倉/平倉/當沖 |
| `account` | Account | Futures account 期貨帳戶 |

> **TAIFEX rejects `MKT`/`MKP` + `ROD`** — on futures/options, MKT and MKP (range market) must pair with IOC or FOK. Only LMT accepts ROD/IOC/FOK.
> **期交所拒絕 `MKT`／`MKP` + `ROD`** — 期貨/選擇權的市價與範圍市價單都必須搭配 IOC 或 FOK；只有 LMT 三種委託條件皆可。

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
contract = api.contracts.get("TXO202401C18000")
if contract is None:
    raise LookupError("option contract not found")

order = sj.FuturesOrder(
    price=100,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.FuturesPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

### Sell Options 賣出選擇權

```python
# Sell put option 賣出賣權
contract = api.contracts.get("TXO202401P17000")
if contract is None:
    raise LookupError("option contract not found")

order = sj.FuturesOrder(
    price=50,
    quantity=1,
    action=sj.Action.Sell,
    price_type=sj.FuturesPriceType.LMT,
    time_in_force=sj.TimeInForce.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_order(contract, order)
```

---

## US Stock Orders 美股下單

Since 1.8.0b1 (pre-release: `pip install --pre shioaji` or
`shioaji==1.8.0b2`). US stock orders use the same `StockOrder`, `place_order`,
`update_order`, `cancel_order`, `update_status` and `list_trades` as Taiwan
orders. They need an IntlAccount (`account_type == sj.AccountType.Intl`, 複委託帳戶) and a US
contract. HK and other markets cannot be ordered.
1.8.0b1（預發行版）起支援。美股下單沿用 `StockOrder` 與同一組下單、改單、刪單、查詢 API，但要用複委託國際帳戶（IntlAccount，`account_type == sj.AccountType.Intl`）和美股商品；港股等其他市場不可下單。

Contents: [order fields](#us-order-fields-美股委託欄位) ·
[local checks and errors](#us-local-checks-and-errors-美股本地檢查與錯誤) ·
[modify and cancel](#us-modify-and-cancel-美股改單與刪單) ·
[reservation orders](#us-reservation-orders-and-the-trading-day-美股預約單與換日) ·
[trade fields](#us-trade-fields-美股委託資料) ·
[reports and reconciliation](#us-order-reports-美股回報).

```python
from decimal import Decimal

import shioaji as sj

api = sj.Shioaji(simulation=True)
api.login(api_key="...", secret_key="...")

contract = api.contracts.get("AAPL", region="US")  # US contract 美股商品
intl = next(a for a in api.list_accounts() if a.account_type == sj.AccountType.Intl)
# login() subscribes every account's reports by default (subscribe_trade=True);
# after login(..., subscribe_trade=False) call api.subscribe_trade(intl) for US reports.

order = sj.StockOrder(
    action="Buy",
    price=Decimal("180.25"),  # Decimal / str / int / float; up to 4 decimals 最多 4 位小數
    quantity=10,            # whole shares (int / str / Decimal) 整數股
    price_type="LMT",       # LMT / MKT
    time_in_force="DAY",    # DAY / OPG / ATC (ROD is taken as DAY)
    account=intl,
    all_or_none=False,      # optional AON 全部成交否則不成交
)
trade = api.place_order(contract, order)

api.update_order(trade, qty=4)   # cancel 4 shares 減量 4 股
api.cancel_order(trade)          # cancel the rest 刪單
api.update_status(intl)          # refresh US trades 查詢美股委託成交
api.list_trades()
```

### US order fields 美股委託欄位

| Field 欄位 | US rule 美股規則 |
|------|------|
| `account` | IntlAccount; omitted = the first IntlAccount. A stock account is rejected. 省略時用第一個國際帳戶（IntlAccount） |
| `quantity` | `int`, `str` or `Decimal`; whole shares, at least 1 (`Decimal("2.0")` counts as 2). A fraction such as `Decimal("0.5")` raises before sending; a `float` raises `TypeError`. 下單只收整數股，不收 float |
| `price` | `Decimal`, `str`, `int` or `float` (a float is read through `str()`, so `173.97` stays `173.97`). Above 0 for LMT, never negative, at most 4 decimals; MKT may send 0. LMT 價格大於 0、最多 4 位小數 |
| `price_type` | `LMT` or `MKT` only |
| `time_in_force` | `DAY`, `OPG` (at the opening), `ATC` (at the close); `ROD` is sent and reported as `DAY`. `IOC` / `FOK` pass the SDK check but the backend rejects them for US stocks (HTTP 400 `UNSUPPORTED_ORDER_COMBINATION`) 美股後台目前只接受 DAY／OPG／ATC |
| `all_or_none` | Optional bool, default `False` |
| `order_lot` | Only `Common` (the default; US quantity is always in shares). Any other lot raises before sending 只接受 Common |
| `order_cond` | Only `Cash` (the default). Any other condition raises before sending 只接受 Cash |
| `daytrade_short` | Not supported for US; `True` raises (leave it `False` / unset) |
| `custom_field` | Not supported for US; setting it raises |

An order at the close is `time_in_force="ATC"`: `MKT` + `ATC` is a market on
close order, `LMT` + `ATC` a limit on close order. There is no `MOC` / `LOC`
price type. 收盤單用 `time_in_force="ATC"`：MKT + ATC 為收盤市價單，LMT + ATC 為收盤限價單。

`MKT`/`OPG`/`ATC` have exchange time windows (OPG and ATC must be sent before
the open/close cut-off); the broker rejects them outside those windows.
各種委託有交易所時段限制，時段外由後台退單。

### US local checks and errors 美股本地檢查與錯誤

The SDK checks a US order before sending for: the price (above 0 for LMT, at
most 4 decimals), whole shares, the IntlAccount, and the Taiwan-only
fields the US wire does not carry (`order_lot` other than `Common`,
`order_cond` other than `Cash`, `daytrade_short=True`, `custom_field`). The
backend would silently ignore those fields and place a different order than
the one asked for, so they raise locally. Every combination rule (which
`time_in_force` goes with which `price_type`, `all_or_none` limits) is checked
by the backend, which rejects an unsupported order with HTTP 400
`UNSUPPORTED_ORDER_COMBINATION`.
SDK 檢查價格、整數股、國際帳戶（IntlAccount），以及美股電文沒有的台股欄位（order_lot 非 Common、order_cond 非 Cash、daytrade_short=True、custom_field），後台會忽略這些欄位而下出不同的單，所以本地直接拒絕；組合限制由後台檢查並回傳 `UNSUPPORTED_ORDER_COMBINATION`。

Local failures raise `sj.ShioajiValueError` (a `ValueError`) in Python with the
text `<api> validation error: <reason>`, and HTTP 400 on the server, before
anything is sent. A `float` quantity raises `TypeError`. Reasons (exact text):
本地檢查失敗時 Python 丟 `ShioajiValueError`（訊息為 `<api> validation error: <原因>`），HTTP 回 400，不會送出。原因原文如下：

| Cause 原因 | Reason text 訊息 |
|---|---|
| Fractional shares 非整數股 | `US order quantity 0.5 is not a whole number of shares; fractional share orders are not supported` |
| Quantity below 1 數量小於 1 | `US order quantity is a whole number of shares and must be at least 1` |
| LMT price 0 or less 限價 ≤ 0 | `US LMT order price must be greater than 0` |
| Negative price 負價 | `US order price must not be negative` |
| More than 4 decimals 超過 4 位小數 | `US order price allows at most 4 decimal places` |
| Not an IntlAccount 非國際帳戶 | `US contracts need an IntlAccount, got account type S` |
| IntlAccount with a Taiwan contract 國際帳戶（IntlAccount）下台股 | `IntlAccounts only trade US contracts` |
| `order_lot` not Common | `order_lot Odd is not supported for US orders: US quantity is always in shares, use order_lot Common (the default)` |
| `order_cond` not Cash | `order_cond MarginTrading is not supported for US orders: US orders are cash only, use order_cond Cash (the default)` |
| `daytrade_short=True` | `daytrade_short is not supported for US orders: leave it False (the default)` |
| `custom_field` set | `custom_field is not supported for US orders` |
| US-only value on a Taiwan contract 台股用了美股值 | `time_in_force DAY is only for US contracts (Taiwan: ROD, IOC, FOK)`, `all_or_none is only for US contracts` |
| HK / JP contract 港股、日股 | `HK orders are not supported yet; only TW and US contracts can be ordered` |
| US futures / options | `US futures and options are not supported` |

Backend rejections are not retried by the SDK: they come back as an error
(Python exception, HTTP 400) with the backend text, for example
`UNSUPPORTED_ORDER_COMBINATION`. Show the text to the user and fix the order;
do not loop on the same request.
後台拒絕時 SDK 不會自動重試，錯誤原文回給呼叫端（Python 例外、HTTP 400）；請把原文告訴使用者並修正委託，不要原樣重送。

### US modify and cancel 美股改單與刪單

- **Reduce quantity only 只能減量.** `update_order(trade, qty=n)` cancels `n`
  more shares; `n` must be a whole number between 1 and the open shares, else
  `US qty is the whole number of shares to cancel and must be between 1 and <open>`.
  A price change (`update_order(trade, price=...)`) raises
  `美股不支援改價，請刪單後重新下單`: cancel and place a new order instead.
  HTTP `/order/update_price` returns 400 for US trades. 美股不支援改價，要刪單重下。
- **Cancel 刪單.** `cancel_order(trade)` cancels all open shares.
- **Active orders only 只能改／刪有效委託.** `update_order` / `cancel_order` of
  a US trade that is no longer active (`Failed`, `Cancelled`, `Filled`, or no
  shares left open) raises before sending, e.g.
  `US order <id> is not active (status Filled, remaining quantity 0) and cannot be updated`
  (`... cannot be cancelled` for `cancel_order`).
  Call `update_status(intl)` first if the cached status may be stale.
  已失敗、已刪除、全部成交或剩餘 0 股的委託不能改單或刪單。
- **Cancelling too soon 太快刪單.** A cancel sent right after the order, before
  the broker has accepted it, is rejected by the backend (code `-2054`, HTTP
  400). The SDK does **not** retry it automatically. Wait for the `New`
  `IntlOrder` report (or `trade.status.status` to leave `PendingSubmit`), then
  cancel again. 下單後馬上刪單會被後台拒絕（-2054，HTTP 400），SDK 不會自動重試；等收到委託成功回報後再刪。
- If the backend reports a fractional order or cancelled quantity for a
  trade, `update_order` / `cancel_order` of it raises locally (the backend
  cannot take a fractional quantity on these calls yet).
- US orders are not available in VPN mode (`vpn=True`).
  美股不支援 VPN 模式。

### US reservation orders and the trading day 美股預約單與換日

- Orders sent outside US trading hours are reservation orders 預約單 and stay
  `PreSubmitted`/`PendingSubmit` until the market opens.
- `trade.order.trade_date` (`YYYYMMDD`) is the US trading day the order
  belongs to; read it instead of guessing from the Taipei clock.
- The SDK's local trade cache (`list_trades`, held `Trade` views,
  `trade_cache_health`) starts a new day at **06:00 Taipei time** for every
  market, US included. After that rollover `list_trades()` no longer returns
  orders cached before 06:00; call `api.update_status(intl)` to load what the
  backend reports now. A reservation order placed before 06:00 Taipei is still
  a live order at the broker even if it disappears from the local cache: check
  with `update_status(intl)` before placing it again. The trade report
  subscription is kept across the rollover.
  SDK 本地委託快取每天台北 06:00 換日（美股也一樣）；換日後 `list_trades()` 不再列出換日前快取的委託，要用 `api.update_status(intl)` 重新載入後台資料。06:00 前下的預約單即使從本地快取消失，在券商端仍是有效委託，重下之前先用 `update_status(intl)` 確認，避免重複下單；回報訂閱不受影響。

### US trade fields 美股委託資料

- `trade.order` carries `all_or_none`, `currency` (`USD`), `region` (`US`),
  `session` and `trade_date`; `trade.status.avg_price` is the
  quantity-weighted average fill price. Taiwan trades leave them `None`.
- **US numbers are `decimal.Decimal` 美股數值為 Decimal.** For US trades,
  `trade.order.price` / `quantity`, `trade.status.order_quantity` /
  `deal_quantity` / `cancel_quantity` / `avg_price` and every deal's `price` /
  `quantity` are exact `Decimal` values, from reports, `update_status` and
  `list_trades` alike. Fills and queried quantities may be fractional shares
  (e.g. `Decimal("0.5")`). `avg_price` is computed exactly and rounded half
  away from zero at 6 decimal places when it does not end sooner. Taiwan
  trades keep `float` prices and `int` quantities.
  美股委託的價格與數量都是精確的 `Decimal`（成交可能有零股小數，例如 0.5 股）；台股維持 float / int。
- `trade.order.session` is a `sj.TradingSession` (`Regular`, `PreMarket`,
  `AfterHours`). A session value this SDK version does not know is left
  `None` with a warning in the log; the trade or report is still delivered.
  交易時段為 `sj.TradingSession`；未知值留空（記錄警告），不影響委託資料。
- `trade.status.status_code` / `trade.status.msg` are the `op_code` / `op_msg`
  of the latest `IntlOrder` report applied to the trade: `"00"` is success; a
  rejected order reads, for example, `status_code "8"`, `msg "REJECTED"` with
  `status == Failed`. Surface `msg` to the user when an order fails.
  `status_code`／`msg` 取自最新一筆美股委託回報的 `op_code`／`op_msg`；`"00"` 為成功，失敗時把 `msg` 告訴使用者。

HTTP: send the US contract (`"region": "US"`) with a `stock_order`; select
the IntlAccount with `"account": {"account_type": "H", "broker_id": ..., "account_id": ...}`
(the type matters when the Intl and stock accounts share an account id).
The HTTP `price` / `quantity` take a JSON number or a decimal string
(`"price": "180.25"`); US trades answer prices and quantities as exact
decimal strings (`"price": "180.25"`, `"deal_quantity": "0.5"`). List US
trades with `POST /api/v1/order/trades` and `{"account_type": "H"}`. CLI:
`shioaji order place --region US --code AAPL --action Buy --price 180.25 --quantity 10 --tif day`.

### US order reports 美股回報

US active reports come as `OrderState.IntlOrder` (`IORDER`, order accepted /
reduced / cancelled / rejected) and `OrderState.IntlDeal` (`IDEAL`, one fill)
on the same `set_order_callback` / `@api.on_order` callback and the same
`order_event` SSE as Taiwan reports, after `subscribe_trade` of the `H`
account. They update the same live `trade` before the callback runs.
美股主動回報為 `IntlOrder`（委託、減量、刪單、退單）與 `IntlDeal`（每筆成交），走同一個 order callback 與 SSE，需先訂閱國際帳戶（IntlAccount）；callback 執行時 `trade` 已更新。

`IntlOrder` payload (`msg[...]` in Python, `data.IntlOrder` in SSE):

| Key | Fields 欄位 |
|---|---|
| `event_id` | `v1:IO:...` receipt ID |
| `operation` | `op_type` (`New`, `UpdateQty`, `Cancel`; a rejected New arrives as `New` with a non-`"00"` code), `op_code` (`"00"` success), `op_msg` |
| `order` | `id`, `seqno`, `ordno` (`""` when the broker has none, e.g. a failed New), `account` (only `account_type` `"H"`, `broker_id`, `account_id` are reported), `action`, `price` / `quantity` (original order quantity) as `Decimal` or `None`, `price_type` (raw string: `LMT`, `MKT`, ...; `""` when not reported), `time_in_force` (raw string: `DAY`, `OPG`, `ATC`, `IOC`, `FOK`, ...), `aon`, `session` (only when the broker sent a known session) |
| `status` | `id`, `exchange_ts` (epoch seconds, float), `cancel_quantity`, `order_quantity` (`Decimal` or `None`), `web_id` |
| `contract` | `code`, `security_type` (`STK`), `region` (`US`), `currency` |

`IntlDeal` payload keys: `event_id` (`v1:ID:...`), `trade_id` (= `order.id` of
the `IntlOrder`), `seqno`, `ordno`, `exchange_seq` (the fill's match number),
`broker_id`, `account_id`, `action`, `code`, `region`, `price` and `quantity`
(`Decimal`; fills may be fractional shares), `web_id`, `ts` (epoch seconds).
In SSE JSON the decimals are strings.
`IntlDeal` 的 `price`、`quantity` 為 `Decimal`（可能是零股小數），SSE 中為字串。

```python
from shioaji import OrderState

def order_cb(stat, msg):
    if stat == OrderState.IntlOrder:
        op = msg["operation"]
        if op["op_code"] != "00":
            print("US order failed:", op["op_msg"])
        else:
            print("US order", op["op_type"], msg["order"]["id"], msg["status"]["order_quantity"])
    elif stat == OrderState.IntlDeal:
        print("US fill", msg["code"], msg["price"], msg["quantity"], msg["exchange_seq"])

api.set_order_callback(order_cb)
```

**Missed reports and reconciliation 缺號與對帳.** `event_id` follows the
same `v1:<stream>:<reset>:<sequence>` rules as Taiwan
([event_id](#event_id-deduplication-and-sequence-gaps-去重與跳號判讀)), with
streams `IO` and `ID`. When a sequence number is skipped,
`api.trade_cache_health(intl)` turns `Degraded` with reason `SequenceGap` for
`IntlOrder` / `IntlDeal`; the SDK does not replay or query by itself. After a
gap, a reconnect, or any doubt, call `api.update_status(intl)` (HTTP
`/order/trades` with `refresh: true`) to reconcile.
`event_id` 規則同台股（前綴 `IO`／`ID`）。跳號時 `trade_cache_health(intl)` 變成 `Degraded`（`SequenceGap`），SDK 不會自動補；缺號、重連或有疑慮時呼叫 `api.update_status(intl)` 對帳。

How a US `update_status` reconciles fills 美股對帳如何補成交:

- The query may answer **one cumulative deal** per trade (`seq` `"1"`, `ts`
  0, the average price and the whole filled quantity) instead of per-fill
  deals. Missed `IntlDeal` reports are **not replayed** one by one: the trade
  gets the correct `deal_quantity`, `avg_price` and status, but
  `trade.status.deals` may hold that single cumulative row.
  對帳只補累計成交（一筆 seq "1" 的彙總），不會逐筆重播漏掉的成交回報；`deal_quantity`、`avg_price`、狀態會正確。
- As soon as a real `IntlDeal` fill is known, the cumulative row leaves
  `deals`; fills are keyed by `exchange_seq`, so a fill seen in both a report
  and a query is counted once.
- A new fill that may or may not already be inside the cumulative row is
  applied without double counting, but health turns `Degraded`
  (`ProjectionFailed`) until the next `update_status(intl)`.
- The Python SDK does not reconcile by itself after a reconnect. The HTTP
  server refills its trade cache with `update_status` for every signed account
  (the IntlAccount included) after each login (startup, daily maintenance, session
  recovery).
  Python SDK 重連後不會自動對帳；HTTP server 每次登入後會對所有已簽署帳戶（含國際帳戶）自動補 trade cache。

`update_status` / `list_trades` for US 美股查詢:

- `api.update_status(intl)` queries the IntlAccount. `api.update_status()`
  without an account resolves the default stock (or futures) account, so pass
  the IntlAccount explicitly for US trades. Only `update_status(account)` reconciles health,
  `update_status(trade=trade)` does not.
- `api.list_trades()` returns Taiwan and US trades from the local cache
  together; tell them apart with `trade.order.account.account_type == sj.AccountType.Intl` or
  `trade.contract.region == "US"`.
- Use `api.trade_cache_health(intl)` to check the US report streams.

---

## Combo Orders 組合單

Combo orders have separate rules for two-leg contracts, net-price
calculation, `combo_type`, TAIFEX order conditions, and combo status
confirmation. Read [COMBO_ORDERS.md](COMBO_ORDERS.md) before placing,
cancelling, or troubleshooting combo orders.

Quick reminders:

- Exactly two `ComboBase` legs are required.
- `ComboOrder.price` is the net combo price, not a per-leg price.
- Per-leg `ComboBase.action` drives the combo direction.
- Standard option combo orders do not support `ROD`; use legal `LMT + IOC`
  or `LMT + FOK` during continuous trading.
- Confirm combo final state with `update_combostatus(account)` and
  `list_combotrades()`.

---

## Modify Orders 改單

For HTTP/JS/Go/Rust/C#/Java clients, update/cancel endpoints do **not** accept a full Python `Trade` object. They accept `trade_id`, which is the nested `Trade.order.id` from the server's trade cache. Since 1.7.8 the server refills its trade cache after every login (startup, daily maintenance, session recovery), so same-day `trade_id`s keep working across server restarts. If the client only knows `ordno`/`seqno`, or the server still reports the trade missing, first call `POST /api/v1/order/trades` with `refresh` omitted or `true`. That runs `update_status(account)`, refreshes the server cache, and returns `Vec<Trade>`. Use `refresh: false` only when the process-local cached snapshot is sufficient. Select the intended trade, then send `trade.order.id`.
HTTP/JS/Go/Rust/C#/Java client 的改單/刪單 endpoint 不吃 Python 的完整 `Trade` 物件，而是吃 `trade_id`，也就是 server trade cache 裡的 `Trade.order.id`。1.7.8 起 server 每次登入後（啟動、每日維護、斷線重建）都會自動補回 trade cache，同一天的 `trade_id` 在 server 重啟後仍可使用。如果 client 只知道 `ordno`/`seqno`，或 server 仍回報找不到該委託，要先用帳號呼叫 `POST /api/v1/order/trades`，並省略 `refresh` 或設為 `true`。這會執行 `update_status(account)`、刷新 server cache、回傳 `Vec<Trade>`；只有確定 process-local cache snapshot 已足夠時才使用 `refresh: false`。選到目標 trade 後，再送 `trade.order.id`。

Do not use a deal-event `trade_id` blindly unless you know it matches the same `Trade.order.id`. The safer HTTP flow is: `/order/trades` -> pick `trade.order.id` -> `/order/update_price`, `/order/update_qty`, or `/order/cancel_order` -> wait for `order_deal_event` or call `/order/trades` again to confirm.
不要盲目使用成交回報裡的 `trade_id`，除非已確認它和同一筆委託的 `Trade.order.id` 對得上。HTTP 較安全流程是：`/order/trades` -> 選 `trade.order.id` -> `/order/update_price`、`/order/update_qty` 或 `/order/cancel_order` -> 等 `order_deal_event` 或再呼叫 `/order/trades` 確認。

### Change Price 改價

For stocks, only limit orders can change price. Odd-lot orders (intraday or after-hours) and market orders cannot; reduce the quantity or cancel instead. US orders can never change price ([US modify and cancel](#us-modify-and-cancel-美股改單與刪單)).
股票只有限價單能改價；零股（盤中／盤後）、市價單不能改價，只能減量或刪單。美股一律不能改價。

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

### Trade Cache Health 委託快取健康狀態

`api.trade_cache_health(account)` (1.7.6+) only inspects the process-local
cache; it does not call `update_status()`. `Healthy` means the subscribed report streams
have baselines and no detected cache issue. `Unknown` means the account is not
subscribed yet or a stream has no baseline. `Degraded` means a reason such as a
sequence gap, pending report, untrackable event ID, or projection failure was
observed. Inspect `health.reasons` for the affected event type and reason code.

`api.trade_cache_health(account)`（1.7.6+）只檢查 process-local cache，不會呼叫
`update_status()`。`Healthy` 表示已訂閱的回報串流具備 baseline，且目前未偵測
到快取問題；`Unknown` 表示帳號尚未訂閱，或串流還沒有 baseline；`Degraded`
表示已觀察到跳號、待關聯回報、無法追蹤的 event ID 或投影失敗等原因。請從
`health.reasons` 查看受影響的事件類型與原因碼。

```python
health = api.trade_cache_health(api.stock_account)
if health.state != sj.TradeCacheHealthState.Healthy:
    for item in health.reasons:
        print(item.event_type, item.reason)
```

Each `health.reasons` item carries `event_type` and `reason`:

| `reason` | Meaning | Clears when |
|---|---|---|
| `NotSubscribed` | The account has no trade-report subscription | `subscribe_trade(account)` succeeds |
| `NoBaseline` | Subscribed, but that stream has not delivered a trackable report yet | The first report arrives on that stream, or `update_status(account)` runs |
| `SequenceGap` | An event ID sequence number was skipped within one stream and reset | The missing report arrives late and projects, or `update_status(account)` runs |
| `PendingReport` | A report cannot be correlated to a cached order yet | The matching order response or New report arrives, or `update_status(account)` runs |
| `UntrackableEventId` | The event ID is missing or not a supported `v1:` ID | `update_status(account)` runs |
| `ProjectionFailed` | A report could not be applied to the cached Trade, such as incomplete identity, product or action mismatch, or conflicting reports | `update_status(account)` runs |

`NotSubscribed` and `NoBaseline` keep the state at `Unknown`; any other reason
makes it `Degraded`. Only `update_status(account)` reconciles health;
`update_status(trade=trade)` does not.

`health.reasons` 的每個項目含 `event_type` 與 `reason`：

| `reason` | 意義 | 何時消失 |
|---|---|---|
| `NotSubscribed` | 該帳戶尚未訂閱交易回報 | `subscribe_trade(account)` 成功 |
| `NoBaseline` | 已訂閱，但該串流尚未收到可追蹤的回報 | 該串流第一筆回報到達，或執行 `update_status(account)` |
| `SequenceGap` | 同一串流、同一重置碼內的 event ID 序號跳號 | 缺少的回報晚到並完成投影，或執行 `update_status(account)` |
| `PendingReport` | 回報尚無法關聯到 cache 中的委託 | 對應的下單回應或 New 回報到達，或執行 `update_status(account)` |
| `UntrackableEventId` | event ID 缺失，或不是支援的 `v1:` ID | 執行 `update_status(account)` |
| `ProjectionFailed` | 回報無法套用到 cache 中的 Trade，例如關聯欄位不全、商品或買賣別不符、回報互相衝突 | 執行 `update_status(account)` |

`NotSubscribed` 與 `NoBaseline` 會讓狀態維持 `Unknown`；其他原因則為 `Degraded`。
只有 `update_status(account)` 會對 health 做對帳，`update_status(trade=trade)` 不會。

Call `update_status(account)` explicitly when `Degraded` must be reconciled,
when active reports may have been missed, or when an authoritative final state
is required. `Unknown` alone can be normal immediately after subscribing; wait
for the stream baseline unless the caller requires immediate reconciliation.

當 `Degraded` 需要對帳、可能漏掉主動回報，或必須立即取得權威最終狀態時，
由 caller 明確呼叫 `update_status(account)`。剛訂閱後的 `Unknown` 可能是正常
狀態；若不需要立即對帳，可先等待串流建立 baseline。

#### HTTP: Trade Cache Health

```bash
# POST /api/v1/order/trade_cache_health (1.7.6+)
curl -X POST http://localhost:8080/api/v1/order/trade_cache_health \
  -H "Content-Type: application/json" \
  -d '{"broker_id":"9A95","account_id":"1234567","account_type":"S"}'
```

| Body | Account 帳戶 |
|---|---|
| `{"account_type":"S"}` | Default stock account 預設股票帳戶 |
| `{"account_type":"F"}` | Default futures/options account 預設期貨／選擇權帳戶 |
| `{}` | Same as `S` 視為 `S` |
| `{"account_type":"H"}` | First IntlAccount (US stock) (1.8.0b1) 第一個國際帳戶（IntlAccount，美股） |
| `{"broker_id":"9A95","account_id":"1234567"}` | That specific account; `account_type` may be omitted 指定帳戶，`account_type` 可省略 |
| `account_type` other than `S`/`F`/`H` 非 `S`/`F`/`H` | HTTP 400 `Invalid account_type` |

The response is `{"state": ..., "reasons": [{"event_type": ..., "reason": ...}]}`,
for example
`{"state":"Unknown","reasons":[{"event_type":"StockDeal","reason":"NoBaseline"}]}`.
Like the Python call, it reads only this running server's cache and does not
call the backend.

回應為 `{"state": ..., "reasons": [{"event_type": ..., "reason": ...}]}`，例如
`{"state":"Unknown","reasons":[{"event_type":"StockDeal","reason":"NoBaseline"}]}`。
與 Python 呼叫相同，只讀取這個 running server 的 cache，不會呼叫後端。

#### HTTP: Get Trades

```bash
# Cache-only: no upstream update_status request.
curl -X POST http://localhost:8080/api/v1/order/trades \
  -H "Content-Type: application/json" \
  -d '{"account_type":"S","refresh":false}'

# Authoritative reconciliation; omitting refresh has the same behavior.
curl -X POST http://localhost:8080/api/v1/order/trades \
  -H "Content-Type: application/json" \
  -d '{"account_type":"S","refresh":true}'
```

`refresh: false` (1.7.6+) returns only this running server's account-filtered
cache and does not call the backend. Use `refresh: true` if active reports may have been
missed or a final status must be reconciled.

### Trade Status Values 交易狀態值

`PendingSubmit` is a normal intermediate response from order APIs. Do not tell users the order was submitted, failed, filled, or cancelled until active reports (Python callback / HTTP SSE) or a reconciliation `update_status()` confirms the later state.
`PendingSubmit` 是下單 API 可能回傳的正常中間狀態，此時還不知道委託的最終結果。要等主動回報（Python callback / HTTP SSE）或補查用的 `update_status()` 確認後續狀態後，才能告訴使用者該單已送出、失敗、成交或取消。

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

Since 1.7.6, Python `Trade` objects backed by the process-local Trade cache are
**live read-only views**. A previously retained `trade.order` or `trade.status`
reference reads the latest state projected from active reports; callers cannot
assign fields to make a local object look like an upstream order change.

1.7.6 起，Python 中連到本機 Trade cache 的 `Trade` 是**唯讀 live view**。先前保存的
`trade.order` 或 `trade.status` reference 會持續讀到主動回報投影後的最新
狀態；不能直接指定欄位來假裝已經向上游改單。

`trade.status.deals` is a read-only live `Sequence[Deal]`, not a mutable Python
list. `len(deals)` and `deals[index]` read the latest fills. Each `for` loop
fixes one snapshot when iteration starts, so fills arriving during that loop do
not change its length. Use `list(deals)` for a fixed fills-only copy.

`trade.status.deals` 是唯讀且持續更新的 `Sequence[Deal]`，不是可修改的
Python list。`len(deals)` 與 `deals[index]` 讀取最新成交；每次 `for` 開始
時會固定該輪迭代內容，因此迭代期間新到的成交不會改變該輪長度。需要只
複製成交明細時，使用 `list(deals)`。

Use `trade.copy()` when order, status, and deals must all come from the same
instant. It takes one Rust Trade snapshot and returns a fixed, read-only
`Trade`; it does not call the backend or `update_status()`.

需要委託、狀態與成交明細全部來自同一時點時，使用 `trade.copy()`。它在
Rust core 內一次取得完整 Trade 狀態，回傳固定且唯讀的 `Trade` 副本；不會
呼叫後端或 `update_status()`。

```python
trade = api.list_trades()[0]
order = trade.order
status = trade.status
deals = status.deals

# The same retained views continue to observe active-report projection.
# 同一組已保存 view 會持續看到主動回報投影後的狀態。
print(order.price, status.status, len(deals))

fills_copy = list(deals)  # fixed fills-only copy / 固定成交清單副本
trade_copy = trade.copy() # fixed whole-Trade copy / 固定整筆 Trade 副本
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
| `OrderState.IntlOrder` / `IORDER` | US stock order accepted/reduced/cancelled/rejected (1.8.0b1) | dict-like event with `operation`, `order`, `status`, `contract` ([fields](#us-order-reports-美股回報)) | `{"state":"IntlOrder","data":{"IntlOrder":{...}}}` |
| `OrderState.IntlDeal` / `IDEAL` | US stock fill (1.8.0b1) | dict-like event with `trade_id`, `seqno`, `ordno`, `exchange_seq`, `broker_id`, `account_id`, `action`, `code`, `region`, `price`, `quantity`, `web_id`, `ts` | `{"state":"IntlDeal","data":{"IntlDeal":{...}}}` |

All six payloads expose top-level `event_id: str` (1.7.6+; US since 1.8.0b1). Live reports require a
nonempty ID. Historical `order_deal_records()` returns `""` when no ID was
saved; skip ID-based deduplication and sequence tracking for these records.
Treat the ID as an opaque string and preserve it exactly.

所有回報（含美股 `IntlOrder`／`IntlDeal`）都提供頂層 `event_id: str`（1.7.6+）。即時回報的 ID 必須非空；歷史 `order_deal_records()` 沒有保存 ID 時回傳 `""`，這些紀錄不參與 ID 去重或序號追蹤。請將 ID 視為不透明字串，原樣保留。

Agent decision rules:

- Match order and deal events with `order.id` / `status.id` to deal `trade_id`.
- Deal events may arrive before order events because exchange message priority can favor deals.
- `operation.op_code == "00"` means the order operation succeeded; other values mean failure and `operation.op_msg` should be surfaced.
- When `place_order()` returns `PendingSubmit`, do not guess final state. Wait for `order_deal_event` first; use `update_status()` or `order_deal_records()` only for reconciliation, missed events, or offline recovery.

---

## Order Callback API 訂單回報 API

Order and deal events are pushed automatically when orders are submitted or filled.
委託及成交事件會在下單或成交時主動推送。

Since 1.7.6, a held `Trade` and `api.list_trades()` are already up to date when
the callback runs, so you do not need to update them yourself.

1.7.6 起，callback 執行時，持有的 `Trade` 與 `api.list_trades()` 已經是最新狀態，
不需要自己去更新它們。

### set_order_callback 設定委託回報

```python
def order_cb(stat, msg):
    print(f"State: {stat}")
    print(f"Event ID: {msg['event_id']}")  # Nonempty producer identity on live callbacks
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
    print(f"Event ID: {msg['event_id']}")
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
sj.OrderState.IntlOrder     # 美股委託回報 (IORDER, 1.8.0b1)
sj.OrderState.IntlDeal      # 美股成交回報 (IDEAL, 1.8.0b1)
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

### HTTP: Order Events via SSE 透過 SSE 接收委託／成交回報

Order events are available through SSE streaming. See [STREAMING.md](STREAMING.md) for SSE details.

委託／成交回報可透過 SSE 接收，詳見 [STREAMING.md](STREAMING.md)。

The existing envelope is unchanged. For example, the `event: order_event`
frame's JSON data contains `{"state":"StockOrder","data":{"StockOrder":{
"event_id":"v1:SO:C6U5mMWBd:BOKZbRr:123", ...}}}` (ellipsis denotes the
unchanged operation/order/status/contract fields). Read
`envelope.data[envelope.state].event_id`. This payload field is not SSE's
transport `id:` field, `Trade.order.id`, request ID or `exchange_seq`. Each
order can have many event IDs.

SSE 的封裝格式維持不變，從 `envelope.data[envelope.state].event_id` 取值。這個欄位不是 SSE 的 `id:`、委託 ID 或成交序號；同一張委託可以有多個事件 ID。以下省略號代表原有的其他回報欄位。

### event_id: Deduplication and Sequence Gaps 去重與跳號判讀

`event_id` is available since 1.7.6. Python callbacks read `msg["event_id"]`;
HTTP SSE clients read `envelope.data[envelope.state].event_id`.

`event_id` 自 1.7.6 起提供。Python callback 讀取 `msg["event_id"]`；HTTP SSE 讀取 `envelope.data[envelope.state].event_id`。

For deduplication, use the complete nonempty ID within the same environment.
An order can have many event IDs. Matching IDs identify a repeated delivery;
different IDs do not prove different business operations.
Callbacks/SSE deliver every decoded report, including repeats, independently
of Trade cache projection. Your application decides how to process them.

去重時，在同一環境使用完整、非空的 ID。相同 ID 表示同一回報再次送達；不同 ID 不保證是不同業務操作。callback／SSE 會交付每筆成功解碼的回報，包含重複回報，與 Trade cache 投影獨立；由你的程式決定如何處理。

For sequence tracking, split a supported `v1:` ID at its last two colons:

追蹤序號時，將支援的 `v1:` ID 從最後兩個冒號拆成以下三段；前綴與重置碼直接當字串使用即可。

`<stream>:<reset>:<sequence>`

Compare decimal sequences only within the same environment, stream and reset.
The first observed sequence establishes a baseline. A new reset establishes
its own baseline; keep late reports from an older reset separate.
A smaller sequence can be a previously unseen late report, so use the complete
ID to decide whether it is a duplicate.

只比較同環境、同前綴、同重置碼的十進位序號。首次收到時建立基準；新的重置碼另建基準，舊輪晚到回報分開處理。較小序號可能是尚未收到過的晚到回報，是否重複仍以完整 ID 判斷。

`123 → 125` means `124` has not yet been observed; it may arrive later.
A gap indicates possible missing reports, not confirmed loss or automatic
replay. Reconciliation is an explicit caller action; sequence tracking does
not call `update_status()`.

`123 → 125` 表示目前尚未觀察到 `124`，它仍可能晚到。跳號只代表可能缺回報，不表示已確定遺失，也不會自動補送或呼叫 `update_status()`；對帳由呼叫者明確要求。

```python
# Supported nonempty v1 IDs only. 僅適用於支援的 v1 非空 ID。
stream, reset, seq_text = event_id.rsplit(":", 2)
sequence = int(seq_text)
# Compare within (environment, stream, reset). 與同環境、前綴及重置碼的最高序號比較。
```

Use `BigInt(seqText)` for exact sequence comparisons in JavaScript.
For unsupported ID formats, retain the raw report and skip sequence inference.

JavaScript 使用 `BigInt(seqText)` 精確比較序號。遇到不支援的 ID 格式時，保留原始回報，略過序號判讀。


---

## Subscribe/Unsubscribe Trade 訂閱/取消訂閱交易回報

Subscribe to order/deal events for a specific account. Production and simulation both support this operation. A successful subscription starts active reports for that account. Use the same explicit-subscribe pattern as market-data subscription (#237).

訂閱特定帳戶的交易事件，啟用即時委託／成交通知。正式環境與測試環境都支援此操作；訂閱成功後開始接收該帳戶的主動回報。消費 `/stream/data/order_event` SSE 前須先對每個帳戶訂閱，操作方式與訂閱報價一致。

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

Call `subscribe_trade` after login for each account whose active reports are needed. A successful `unsubscribe_trade` stops reports for that account. See [STREAMING.md](STREAMING.md) and [HTTP_API.md](HTTP_API.md#post-apiv1authsubscribe_trade) for full SSE/endpoint reference.

---

## Best Practices 最佳實踐

### 1. Use Callbacks for Real-time Status 使用主動回報獲取即時狀態

Since 1.7.6, active reports update `Trade` state automatically. Use the order
callback as a reminder to read `Trade`; there is no need to poll `update_status()`.
1.7.6 起內建以主動回報更新 `Trade` 狀態，可用 order callback 當作提醒再去讀 `Trade`，
不需要反覆呼叫 `update_status()`。

Just check `api.trade_cache_health(account)`, and call `update_status(account)`
when it is `Degraded`, in case reports were missed because of a network drop or
other uncontrollable causes. For `Unknown`, follow `health.reasons`; see
[Trade Cache Health](#trade-cache-health-委託快取健康狀態).
唯需確認 `api.trade_cache_health(account)`，為 `Degraded` 時再呼叫
`update_status(account)`，以防網路斷線等不可控因素造成回報漏接。為 `Unknown` 時
請依 `health.reasons` 處理，詳見 [Trade Cache Health](#trade-cache-health-委託快取健康狀態)。

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
