# Advanced Features 進階功能

This document covers non-blocking mode, stop orders, historical data patterns, and best practices.
Shioaji provides both Python callbacks and HTTP API + SSE streaming as alternative approaches.
本文件說明非阻塞模式、觸價委託、歷史數據模式和最佳實踐。
shioaji 同時提供 Python 回調和 HTTP API + SSE 串流作為替代方案。

Use [MIGRATION.md](MIGRATION.md) for deprecated-code migration. Use the matching functional reference when HTTP/SSE response handling or order decision logic matters.

## Table of Contents 目錄

- [Non-blocking Mode 非阻塞模式](#non-blocking-mode-非阻塞模式)
- [Quote Binding 報價綁定](#quote-binding-報價綁定)
- [Stop Orders 觸價委託](#stop-orders-觸價委託)
- [Historical Data 歷史數據](#historical-data-歷史數據)
- [K-bars K 線資料](#k-bars-k-線資料)
- [Snapshots 快照](#snapshots-快照)
- [Scanners 掃描器](#scanners-掃描器)
- [Rate Limits 速率限制](#rate-limits-速率限制)
- [HTTP API and SSE Alternatives HTTP API 與 SSE 替代方案](#http-api-and-sse-alternatives-http-api-與-sse-替代方案)
- [Best Practices 最佳實踐](#best-practices-最佳實踐)

---

## Non-blocking Mode 非阻塞模式

Non-blocking mode allows functions to return immediately without waiting for exchange response.
非阻塞模式讓函數立即返回，無需等待交易所回應。

### Performance 效能

| Mode 模式 | Time 時間 |
|-----------|-----------|
| Blocking 阻塞 | ~0.136 sec |
| Non-blocking 非阻塞 | ~0.012 sec (**12x faster**) |

### Basic Usage 基本用法

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Set timeout=0 for non-blocking 設定 timeout=0 為非阻塞
trade = api.place_order(contract, order, timeout=0)
# Returns immediately with an initial placeholder/intermediate Trade.
# 立即返回初始 placeholder／中間狀態的 Trade。
```

For order APIs, non-blocking mode does not mean the exchange has accepted, rejected, filled, or cancelled the order. Treat the returned `Trade` as an initial object, then wait for `order_deal_event` through Python order callbacks, or use `update_status()` only for reconciliation if active reports were unavailable or missed. See [ORDERS.md](ORDERS.md).
對下單 API 來說，非阻塞不代表交易所已接受、拒絕、成交或取消。請把回傳的 `Trade` 視為初始物件，接著等待 Python order callback 收到的 `order_deal_event`；只有在無法使用或疑似漏掉主動回報時，才用 `update_status()` 補查。詳見 [ORDERS.md](ORDERS.md)。

With `timeout=0`, the immediately returned `Trade` is a placeholder: `trade.order.id`, `seqno`, and `ordno` can be empty strings. Do not anchor hedge, cancel, or risk logic on the immediate return value. Use the per-order `cb=` callback or active order/deal callback event and key off the `seqno` / order identifiers delivered there.
使用 `timeout=0` 時，立即回傳的 `Trade` 是 placeholder：`trade.order.id`、`seqno`、`ordno` 可能是空字串。不要用當下回傳值定錨避險、刪單或風控邏輯；請用單筆 `cb=` callback 或主動委託/成交 callback 事件，並以 callback 中的 `seqno` / 委託識別欄位為準。

### Get Results via Callback 透過回調取得結果

```python
from shioaji import Trade

# Method 1: Order callback 委託回報
def order_cb(stat, msg):
    print(f"Status: {stat}, Message: {msg}")

api.set_order_callback(order_cb)

# Method 2: Per-order callback 單筆回調
def non_blocking_cb(trade: Trade):
    print(f"Trade: {trade}")
    print(f"Order ID: {trade.order.id}")
    print(f"Status: {trade.status.status}")

trade = api.place_order(contract, order, timeout=0, cb=non_blocking_cb)
```

### Supported Functions 支援的函數

All these functions support `timeout=0` for non-blocking:
以下函數皆支援 `timeout=0` 非阻塞：

- `place_order()` - 下單
- `update_order()` - 改單
- `cancel_order()` - 刪單
- `update_status()` - 更新狀態
- `list_positions()` - 持倉查詢
- `list_position_detail()` - 持倉明細
- `list_profit_loss()` - 損益查詢
- `margin()` - 保證金查詢
- `ticks()` - 歷史 Tick
- `kbars()` - 歷史 K 線

---

## Quote Binding 報價綁定

Quote binding mode allows you to store tick/bidask in queue, push to Redis, or trigger stop orders.
報價綁定模式讓你可以將 tick/bidask 存入佇列、推送到 Redis 或觸發觸價單。

### Set Context 設定 Context

```python
from collections import defaultdict, deque
from shioaji import TickSTKv1

# Create message queue 建立訊息佇列
msg_queue = defaultdict(deque)

# Set context 設定 context
api.set_context(msg_queue)
```

### Use bind=True 使用 bind=True

Legacy examples may show `def quote_callback(context, exchange, tick)` for bound quote callbacks. That shape is compatible but deprecated by the current binding because the effective callback still looks like legacy `(exchange, data)`. Generate new code as `(context, tick)`.
舊範例可能以 `def quote_callback(context, exchange, tick)` 示範 bound quote callback。這個形狀可相容運作，但目前 binding 會視為 legacy `(exchange, data)` 並發出 deprecation warning。新程式請產生 `(context, tick)`。

```python
# Method 1: Decorator with bind=True
# 方法一：使用 bind=True 裝飾器
@api.on_tick_stk_v1(bind=True)
def quote_callback(context, tick: TickSTKv1):
    # `context` is the object set by api.set_context(msg_queue)
    # `context` 是 api.set_context(msg_queue) 設定的物件
    context[tick.code].append(tick)

# Method 2: Setter syntax
# 方法二：setter 寫法
def quote_callback(context, tick: TickSTKv1):
    context[tick.code].append(tick)

api.set_on_tick_stk_v1_callback(quote_callback, bind=True)
```

### Push to Redis Stream 推送到 Redis

```python
import redis
import json
from shioaji import TickFOPv1

# Redis connection Redis 連線
r = redis.Redis(host='localhost', port=6379, db=0)

# Set Redis as context 設定 Redis 為 context
api.set_context(r)

@api.on_tick_fop_v1(bind=True)
def quote_callback(context, tick: TickFOPv1):
    channel = f"Q:{tick.code}"
    # Push to Redis stream 推送到 Redis stream
    context.xadd(channel, {'tick': json.dumps(tick.to_dict(raw=True))})
```

### Quote Manager Pattern 報價管理器模式

```python
from typing import List
import polars as pl
from shioaji import TickSTKv1

class QuoteManager:
    def __init__(self, api):
        self.api = api
        self.ticks: List[TickSTKv1] = []
        # Register callback 註冊回調
        api.set_on_tick_stk_v1_callback(self._on_tick)

    def _on_tick(self, tick: TickSTKv1):
        self.ticks.append(tick)

    def get_dataframe(self) -> pl.DataFrame:
        if not self.ticks:
            return pl.DataFrame()

        return pl.DataFrame([t.to_dict() for t in self.ticks]).select(
            pl.col("datetime", "code"),
            pl.col("close").cast(pl.Float64).alias("price"),
            pl.col("volume").cast(pl.Int64),
            pl.col("tick_type").cast(pl.Int8),
        )

    def get_kbars(self, unit: str = "1m") -> pl.DataFrame:
        df = self.get_dataframe()
        if df.is_empty():
            return df

        return df.group_by(
            pl.col("datetime").dt.truncate(unit),
            pl.col("code"),
            maintain_order=True,
        ).agg(
            pl.col("price").first().alias("open"),
            pl.col("price").max().alias("high"),
            pl.col("price").min().alias("low"),
            pl.col("price").last().alias("close"),
            pl.col("volume").sum().alias("volume"),
        )

# Usage 使用方式
qm = QuoteManager(api)
api.subscribe(api.Contracts.Stocks["2330"], quote_type=sj.QuoteType.Tick)

# Later... 稍後...
df = qm.get_kbars("5m")
```

### With Technical Indicators 搭配技術指標

```python
import polars_talib as plta

# Get kbars with indicators 取得帶指標的 K 線
df = qm.get_kbars("5m").with_columns([
    pl.col("close").ta.ema(5).over("code").alias("ema5"),
    pl.col("close").ta.ema(20).over("code").alias("ema20"),
    plta.macd(pl.col("close"), 12, 26, 9).over("code").struct.field("macd"),
])
```

---

## Stop Orders 觸價委託

Stop orders automatically convert to limit/market orders when price reaches trigger level.
觸價委託在價格達到設定價位時，自動轉為限價單或市價單。

### Implementation 實作

```python
from shioaji import TickFOPv1
from typing import List, Dict, Any

class StopOrderExecutor:
    def __init__(self, api):
        self.api = api
        self._stop_orders: Dict[str, List[Dict[str, Any]]] = {}

    def on_tick(self, tick: TickFOPv1):
        """Handle tick and check stop orders 處理 tick 並檢查觸價"""
        code = tick.code
        if code not in self._stop_orders:
            return

        price = float(tick.close)

        for stop_order in self._stop_orders[code]:
            if stop_order["executed"]:
                continue

            # Check trigger condition 檢查觸發條件
            is_triggered = False
            if stop_order["stop_price"] >= stop_order["ref_price"]:
                # Stop above reference (e.g., buy stop)
                # 高於參考價觸發（如買進停損）
                if price >= stop_order["stop_price"]:
                    is_triggered = True
            else:
                # Stop below reference (e.g., sell stop)
                # 低於參考價觸發（如賣出停損）
                if price <= stop_order["stop_price"]:
                    is_triggered = True

            if is_triggered:
                trade = self.api.place_order(
                    stop_order["contract"],
                    stop_order["pending_order"]
                )
                stop_order["executed"] = True
                print(f"Stop order triggered: {code} @ {price}, initial={trade.status.status}")
                # Wait for order_deal_event or reconcile with update_status()
                # before treating the order as submitted/filled/cancelled.

    def add_stop_order(self, contract, stop_price: float, order):
        """Add a stop order 新增觸價委託"""
        code = contract.code

        # Get reference price 取得參考價
        snap = self.api.snapshots([contract])[0]
        ref_price = 0.5 * (float(snap.buy_price) + float(snap.sell_price))

        stop_order = {
            "code": code,
            "stop_price": stop_price,
            "ref_price": ref_price,
            "contract": contract,
            "pending_order": order,
            "executed": False,
        }

        if code not in self._stop_orders:
            self._stop_orders[code] = []
        self._stop_orders[code].append(stop_order)

        return stop_order
```

### Usage 使用方式

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)  # Use simulation while developing
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Create stop order executor 建立觸價執行器
soe = StopOrderExecutor(api)

# Define contract and order 定義合約和訂單
contract = api.Contracts.Futures["TXFC0"]
order = sj.FuturesOrder(
    action=sj.Action.Buy,
    price=18000,
    quantity=1,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

# Add stop order (trigger when price >= 18005)
# 新增觸價委託（價格 >= 18005 時觸發）
soe.add_stop_order(contract=contract, stop_price=18005, order=order)

# Bind callback with context 綁定回調與 context
api.set_context(soe)

@api.on_tick_fop_v1(bind=True)
def on_tick(executor, tick: TickFOPv1):
    executor.on_tick(tick)

# Subscribe to quotes 訂閱行情
api.subscribe(contract, quote_type=sj.QuoteType.Tick)
```

For production stop-order executors, explicitly switch to `sj.Shioaji(simulation=False)`, activate CA, and add account/risk checks before calling `place_order`. Keep `executed=True` or an equivalent idempotency guard so a burst of ticks cannot submit duplicate orders.
正式環境的觸價委託執行器需明確切換 `sj.Shioaji(simulation=False)`、啟用 CA，並在 `place_order` 前加入帳戶與風控檢查。請保留 `executed=True` 或等效的冪等保護，避免連續 tick 重複送單。

After a stop executor calls `place_order`, use the same order-decision rules as normal orders: `PendingSubmit` is intermediate, and final state comes from `order_deal_event` or a reconciliation `update_status()` call.
觸價執行器呼叫 `place_order` 後，仍使用一般下單的判斷規則：`PendingSubmit` 是中間狀態，最終狀態來自 `order_deal_event` 或補查用的 `update_status()`。

---

## Historical Data 歷史數據

### Ticks 逐筆成交

```python
import shioaji as sj

# Full day ticks 全天 Ticks
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2024-01-16"
)

# Time range 時間區段
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2024-01-16",
    query_type=sj.TicksQueryType.RangeTime,
    time_start="09:00:00",
    time_end="09:30:00"
)

# Last N ticks 最後 N 筆
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    query_type=sj.TicksQueryType.LastCount,
    last_cnt=100
)
```

### Ticks Attributes Ticks 屬性

These are Python `api.ticks()` wrapper attributes. HTTP `/api/v1/data/ticks` returns server JSON with `datetime`; do not type HTTP/JS/Go/Rust/C#/Java clients from Python's `ticks.ts`. Use [MARKET_DATA.md](MARKET_DATA.md) for response decisions.
以下是 Python `api.ticks()` wrapper 屬性。HTTP `/api/v1/data/ticks` 回傳 server JSON，時間欄位是 `datetime`；不要直接拿 Python 的 `ticks.ts` 去替 HTTP/JS/Go/Rust/C#/Java client 定型。行情 response 決策請看 [MARKET_DATA.md](MARKET_DATA.md)。

```python
ticks.ts           # List[int]: Timestamps 時間戳
ticks.close        # List[Decimal]: Close prices 成交價
ticks.volume       # List[int]: Volumes 成交量
ticks.bid_price    # List[Decimal]: Bid prices 委買價
ticks.ask_price    # List[Decimal]: Ask prices 委賣價
ticks.bid_volume   # List[int]: Bid volumes 委買量
ticks.ask_volume   # List[int]: Ask volumes 委賣量
ticks.tick_type    # List[int]: 1=Buy, 2=Sell, 0=Unknown
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

df = pl.DataFrame({
    "ts": ticks.ts,
    "close": [float(p) for p in ticks.close],
    "volume": ticks.volume,
    "tick_type": ticks.tick_type,
}).with_columns(
    pl.col("ts").cast(pl.Datetime("ms"))
)
```

---

## K-bars K 線資料

### Query Kbars 查詢 K 線

```python
kbars = api.kbars(
    contract=api.Contracts.Stocks["2330"],
    start="2024-01-15",
    end="2024-01-16"
)
```

### Kbars Attributes K 線屬性

These are Python `api.kbars()` wrapper attributes. HTTP `/api/v1/data/kbars` returns server JSON with `datetime`; do not type HTTP/JS/Go/Rust/C#/Java clients from Python's `kbars.ts`. Use [MARKET_DATA.md](MARKET_DATA.md) for response decisions.
以下是 Python `api.kbars()` wrapper 屬性。HTTP `/api/v1/data/kbars` 回傳 server JSON，時間欄位是 `datetime`；不要直接拿 Python 的 `kbars.ts` 去替 HTTP/JS/Go/Rust/C#/Java client 定型。行情 response 決策請看 [MARKET_DATA.md](MARKET_DATA.md)。

```python
kbars.ts       # List[int]: Timestamps 時間戳
kbars.Open     # List[Decimal]: Open prices 開盤價
kbars.High     # List[Decimal]: High prices 最高價
kbars.Low      # List[Decimal]: Low prices 最低價
kbars.Close    # List[Decimal]: Close prices 收盤價
kbars.Volume   # List[int]: Volumes 成交量
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

df = pl.DataFrame({
    "ts": kbars.ts,
    "open": [float(p) for p in kbars.Open],
    "high": [float(p) for p in kbars.High],
    "low": [float(p) for p in kbars.Low],
    "close": [float(p) for p in kbars.Close],
    "volume": kbars.Volume,
}).with_columns(
    pl.col("ts").cast(pl.Datetime("ms"))
)
```

### Continuous Futures 連續期貨合約

Use R1 (near month), R2 (next month) for continuous data:
使用 R1（近月）、R2（次月）取得連續數據：

```python
# Near month continuous contract 近月連續合約
contract = api.Contracts.Futures.TXF.TXFR1
kbars = api.kbars(contract, start="2024-01-15", end="2024-01-16")

# Next month 次月
contract = api.Contracts.Futures.TXF.TXFR2
```

### Data History 資料歷史

| Product 商品 | Available From 可用起始日 |
|--------------|---------------------------|
| Index/Stock 指數/股票 | 2020-03-02 |
| Futures 期貨 | 2020-03-22 |

---

## Snapshots 快照

Get current market data for multiple contracts:
取得多個合約的當前市場數據：

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
    api.Contracts.Futures["TXFC0"],
]

# Max 500 contracts 最多 500 個合約
snapshots = api.snapshots(contracts)

for snap in snapshots:
    print(f"{snap.code}: {snap.close} ({snap.change_rate}%)")
```

### Snapshot Attributes 快照屬性

These attributes describe Python `api.snapshots()` objects. HTTP `POST /api/v1/data/snapshots` returns server JSON with `datetime` instead of Python `snap.ts`; use [MARKET_DATA.md](MARKET_DATA.md) before typing HTTP/JS/Go/Rust/C#/Java clients.
以下屬性描述 Python `api.snapshots()` 物件。HTTP `POST /api/v1/data/snapshots` 回傳 server JSON，使用 `datetime` 而不是 Python 的 `snap.ts`；撰寫 HTTP/JS/Go/Rust/C#/Java client 欄位前請查 [MARKET_DATA.md](MARKET_DATA.md)。

```python
snap.ts              # int: Timestamp 時間戳
snap.code            # str: Contract code 合約代碼
snap.exchange        # str: Exchange 交易所
snap.open            # Decimal: Open price 開盤價
snap.high            # Decimal: High price 最高價
snap.low             # Decimal: Low price 最低價
snap.close           # Decimal: Close/Last price 收盤/最新價
snap.volume          # int: Volume 成交量
snap.total_volume    # int: Total volume 總成交量
snap.amount          # Decimal: Amount 成交金額
snap.total_amount    # Decimal: Total amount 總成交金額
snap.change_price    # Decimal: Price change 漲跌價
snap.change_rate     # Decimal: Change rate % 漲跌幅
snap.buy_price       # Decimal: Best bid 最佳買價
snap.buy_volume      # int: Bid volume 買量
snap.sell_price      # Decimal: Best ask 最佳賣價
snap.sell_volume     # int: Ask volume 賣量
snap.volume_ratio    # Decimal: Yesterday volume ratio 昨量比
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

df = pl.DataFrame([
    {
        "code": snap.code,
        "close": float(snap.close),
        "volume": snap.total_volume,
        "change_rate": float(snap.change_rate),
    }
    for snap in snapshots
])
```

---

## Scanners 掃描器

Get ranked market data by various criteria:
依各種條件取得排行資料：

### Scanner Types 掃描器類型

```python
import shioaji as sj

# By change percent 依漲跌幅
sj.ScannerType.ChangePercentRank

# By change price 依漲跌價
sj.ScannerType.ChangePriceRank

# By day range (high-low) 依當日振幅
sj.ScannerType.DayRangeRank

# By volume 依成交量
sj.ScannerType.VolumeRank

# By amount 依成交金額
sj.ScannerType.AmountRank
```

### Query Scanners 查詢掃描器

```python
# Top 10 gainers 漲幅前 10 名
scanners = api.scanners(
    scanner_type=sj.ScannerType.ChangePercentRank,
    ascending=False,  # Descending 由大到小
    count=10
)

# Top 10 losers 跌幅前 10 名
scanners = api.scanners(
    scanner_type=sj.ScannerType.ChangePercentRank,
    ascending=True,  # Ascending 由小到大
    count=10
)

# Top 10 by volume 成交量前 10 名
scanners = api.scanners(
    scanner_type=sj.ScannerType.VolumeRank,
    ascending=False,
    count=10
)
```

### Scanner Attributes 掃描器屬性

```python
scan.date            # str: Trade date 交易日
scan.code            # str: Stock code 股票代碼
scan.name            # str: Stock name 股票名稱
scan.close           # Decimal: Close price 收盤價
scan.volume          # int: Volume 成交量
scan.amount          # Decimal: Amount 成交金額
scan.change_price    # Decimal: Price change 漲跌價
scan.change_rate     # Decimal: Change rate % 漲跌幅
scan.bid_orders      # int: Buy-side orders 內盤成交單量
scan.ask_orders      # int: Sell-side orders 外盤成交單量
scan.yesterday_volume # int: Yesterday volume 昨日成交量
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

df = pl.DataFrame([
    {
        "code": scan.code,
        "name": scan.name,
        "close": float(scan.close),
        "change_rate": float(scan.change_rate),
        "volume": scan.volume,
    }
    for scan in scanners
])
```

---

## Rate Limits 速率限制

| Category 類別 | Limit 限制 |
|---------------|------------|
| Quote query 行情查詢 | 50 / 5 sec |
| Accounting 帳務 | 25 / 5 sec |
| Orders 委託 | 250 / 10 sec |

---

## HTTP API and SSE Alternatives HTTP API 與 SSE 替代方案

Shioaji provides HTTP API and SSE streaming as alternatives to Python callbacks. These approaches enable multi-language integration and decoupled architectures.
Shioaji 提供 HTTP API 和 SSE 串流作為 Python 回調的替代方案，可實現多語言整合和解耦架構。

### SSE Streaming Instead of Quote Callbacks 以 SSE 串流取代報價回調

Instead of using Python quote callbacks and `bind=True`, you can consume real-time data via SSE from any language:
除了使用 Python 報價回調和 `bind=True`，你可以從任何語言透過 SSE 消費即時數據：

```bash
# Subscribe first 先訂閱
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"STK","exchange":"TSE","code":"2330","quote_type":"Tick"}'

# Listen to SSE stream 監聽 SSE 串流
curl -N http://localhost:8080/api/v1/stream/data/tick_stk
```

For futures continuous-month aliases such as `TXFR1` / `TXFR2`, resolve the contract first and include the returned `target_code` in the subscribe body. Regular futures codes do not need this. For order events in production, call `POST /api/v1/auth/subscribe_trade` once per account before opening `/api/v1/stream/data/order_event`; simulation does not require it.
期貨連續月 alias（如 `TXFR1` / `TXFR2`）要先查合約並在訂閱 body 放入回傳的 `target_code`；一般期貨代碼不需要。正式環境的委託回報要先對每個帳戶呼叫一次 `POST /api/v1/auth/subscribe_trade`，再打開 `/api/v1/stream/data/order_event`；simulation 不需要。

### HTTP API Instead of Non-blocking Mode 以 HTTP API 取代非阻塞模式

HTTP requests are inherently asynchronous from the caller's perspective. The HTTP server applies its own timeout behavior:
HTTP 請求從呼叫端角度本身就是非同步的。HTTP 伺服器會套用自己的逾時行為：

```bash
## Disabled by default. Confirm simulation/production mode, account,
## payload, response status, and order-event handling in ORDERS.md before enabling.
# curl -X POST http://localhost:8080/api/v1/order/place_order \
#   -H "Content-Type: application/json" \
#   -d '{"contract":{"security_type":"STK","exchange":"TSE","code":"2330"},"stock_order":{"action":"Buy","price":580,"quantity":1,"price_type":"LMT","order_type":"ROD","order_lot":"Common","order_cond":"Cash"}}'
```

Use `stock_order` for stocks and `futures_order` for futures/options. The response is nested `Trade { contract, order, status, deals }`; branch on `trade.status.status` and use [ORDERS.md](ORDERS.md) before assuming final order state.
股票使用 `stock_order`，期貨／選擇權使用 `futures_order`。回應是巢狀 `Trade { contract, order, status, deals }`；請依 `trade.status.status` 判斷，並先查 [ORDERS.md](ORDERS.md)，不要假設委託已完成。

### When to Use Each Approach 何時使用各方案

| Approach 方案 | Best For 適用場景 |
|---------------|-------------------|
| Python callbacks 回調 | Single-process Python trading systems 單行程 Python 交易系統 |
| HTTP API | Multi-language clients, microservices 多語言客戶端、微服務 |
| SSE streaming | Real-time dashboards, external consumers 即時儀表板、外部消費者 |
| CLI | Quick queries, scripting, automation 快速查詢、腳本、自動化 |

See [HTTP_API.md](HTTP_API.md) and [STREAMING.md](STREAMING.md) for full endpoint references.

---

## Best Practices 最佳實踐

### 1. Use Non-blocking for Batch Orders 批量下單使用非阻塞

```python
orders = [...]  # Multiple orders
trades = []

for contract, order in orders:
    trade = api.place_order(contract, order, timeout=0)
    trades.append(trade)

# Handle final order states from order_deal_event callbacks.
# 從 order_deal_event callback 處理最終委託狀態。
```

### 2. Minimize Computation in Callbacks 回調中最小化計算

```python
from queue import Queue

tick_queue = Queue()

@api.on_tick_stk_v1()
def on_tick(tick):
    # Just enqueue, don't process 僅入列，不處理
    tick_queue.put(tick)

# Process in separate thread 在另一個執行緒處理
def process_ticks():
    while True:
        tick = tick_queue.get()
        # Heavy processing here 在這裡做複雜處理
```

### 3. Use Polars for Multi-symbol Analysis 使用 Polars 進行多商品分析

```python
import polars as pl

def analyze_kbars(symbols: list) -> pl.DataFrame:
    all_data = []

    for symbol in symbols:
        contract = api.Contracts.Stocks[symbol]
        kbars = api.kbars(contract, start="2024-01-01", end="2024-01-31")

        df = pl.DataFrame({
            "code": [symbol] * len(kbars.ts),
            "ts": kbars.ts,
            "close": [float(p) for p in kbars.Close],
            "volume": kbars.Volume,
        })
        all_data.append(df)

    return pl.concat(all_data).with_columns([
        pl.col("close").pct_change().over("code").alias("return"),
        pl.col("close").rolling_mean(20).over("code").alias("sma20"),
    ])
```

### 4. Use SSE for Cross-language Streaming 跨語言串流使用 SSE

When building trading systems in languages other than Python, use the HTTP server with SSE streaming instead of Python callbacks:
在非 Python 語言建構交易系統時，使用 HTTP 伺服器搭配 SSE 串流取代 Python 回調：

```javascript
// JavaScript example — consume SSE stream
// JavaScript 範例 — 消費 SSE 串流
const es = new EventSource("http://localhost:8080/api/v1/stream/data");
es.addEventListener("tick_stk", (event) => {
    const tick = JSON.parse(event.data);
    console.log(`${tick.date} ${tick.time} ${tick.code}: ${tick.close} x ${tick.volume}`);
});
```
