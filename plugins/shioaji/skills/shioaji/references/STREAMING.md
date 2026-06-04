# Streaming Market Data 即時行情

This document covers subscribing to real-time market data in Shioaji via Python callbacks and HTTP SSE.
本文件說明如何在 Shioaji 中透過 Python 回調和 HTTP SSE 訂閱即時行情資料。

Use [MIGRATION.md](MIGRATION.md) when old code uses legacy quote helpers or submodule constants. This file owns subscribe/unsubscribe responses and SSE event payload decisions.

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Subscribe / Unsubscribe 訂閱與取消訂閱](#subscribe--unsubscribe-訂閱與取消訂閱)
- [Streaming Response and Decision Summary 即時串流回應與決策摘要](#streaming-response-and-decision-summary-即時串流回應與決策摘要)
- [Python Callbacks 行情回調](#python-callbacks-行情回調)
- [Async Callbacks 非同步回調](#async-callbacks-非同步回調)
- [Python Receivers Python 接收器](#python-receivers-python-接收器)
- [Callback Reference 回調參考](#callback-reference-回調參考)
- [System Callbacks 系統回調](#system-callbacks-系統回調)
- [SSE Streaming (HTTP) SSE 串流](#sse-streaming-http-sse-串流)
- [Best Practices 最佳實踐](#best-practices-最佳實踐)

---

## Overview 概覽

Shioaji provides real-time streaming data through two mechanisms:
shioaji 透過兩種機制提供即時串流資料：

1. **Python callbacks** -- Direct function callbacks for `Shioaji` (sync) and `ShioajiAsync` (async)
2. **SSE (Server-Sent Events)** -- HTTP streaming via the built-in server, accessible from any language

**Quote Types 報價類型:**
- **Tick**: Trade-by-trade data 逐筆成交
- **BidAsk**: Order book (5 levels) 五檔委託
- **Quote**: Aggregated quote data 彙總報價

---

## Subscribe / Unsubscribe 訂閱與取消訂閱

### Python 訂閱

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Register callbacks before subscribing so early ticks are not missed.
# 先註冊 callback 再訂閱，避免剛訂閱後的事件漏接。
@api.on_tick_stk_v1()
def on_tick(tick):
    if tick.intraday_odd:
        print(f"[盤中零股] {tick.code} close={tick.close} vol={tick.volume}")
    else:
        print(f"[一般] {tick.code} close={tick.close} vol={tick.volume}")

# Subscribe tick data 訂閱逐筆成交
api.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.QuoteType.Tick,
)

# Subscribe bidask data 訂閱五檔
api.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.QuoteType.BidAsk,
)

# Subscribe futures tick 訂閱期貨 Tick
api.subscribe(
    api.Contracts.Futures["TXFC0"],
    quote_type=sj.QuoteType.Tick,
)

# Intraday odd lot 盤中零股 - Tick
api.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.QuoteType.Tick,
    intraday_odd=True,
)

# Intraday odd lot 盤中零股 - BidAsk (五檔)
api.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.QuoteType.BidAsk,
    intraday_odd=True,
)

# Unsubscribe 取消訂閱
api.unsubscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.QuoteType.Tick,
)
```

### HTTP: Subscribe / Unsubscribe

```bash
# POST /api/v1/stream/subscribe
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{
    "security_type": "STK",
    "exchange": "TSE",
    "code": "2330",
    "quote_type": "Tick",
    "intraday_odd": false
  }'

# POST /api/v1/stream/unsubscribe
curl -X POST http://localhost:8080/api/v1/stream/unsubscribe \
  -H "Content-Type: application/json" \
  -d '{
    "security_type": "STK",
    "exchange": "TSE",
    "code": "2330",
    "quote_type": "Tick",
    "intraday_odd": false
  }'
```

### Multiple Subscriptions 多重訂閱

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
    api.Contracts.Stocks["2454"],
]

for contract in contracts:
    api.subscribe(contract, quote_type=sj.QuoteType.Tick)
```

---

## Streaming Response and Decision Summary 即時串流回應與決策摘要

Use this table before generating client code. Python receives typed callback objects; HTTP, CLI, JavaScript, Go, Rust, C#, C++, and Java receive server JSON/SSE shapes.
產生 client code 前先看這張表。Python 收到 typed callback object；HTTP、CLI、JavaScript、Go、Rust、C#、C++、Java 收到 server JSON/SSE 形狀。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| Subscribe market data | `api.subscribe(contract, quote_type=..., intraday_odd=...)`; normal use relies on callbacks/receivers, not a JSON response | `POST /api/v1/stream/subscribe` returns `SubscriptionResponse { success, message, subscription }` | Stream commands subscribe before opening SSE; `--format json` follows HTTP JSON where available | If `success=false` or the POST errors, do not open SSE as if subscribed. Check contract, `quote_type`, `intraday_odd`, and HTTP body. |
| Unsubscribe market data | `api.unsubscribe(contract, quote_type=...)` | `POST /api/v1/stream/unsubscribe` returns `SubscriptionResponse { success, message, subscription }` | Stream commands unsubscribe on exit when they created the subscription | Treat `success=true` as accepted. If it errors, report the failed unsubscribe; do not invent a remaining subscription state. |
| Market-data SSE | Python callbacks receive `TickSTKv1`, `BidAskSTKv1`, `TickFOPv1`, `BidAskFOPv1`, quote objects, or receiver values | `GET /api/v1/stream/data/*` is SSE. Each event has `event:` and JSON `data:`; heartbeat events are keep-alive only | CLI stream prints events from the SSE channel after subscribe | Parse `event:` first, then decode `data:` for that channel. A heartbeat means the connection is alive, not that market data arrived. |
| Stock/FOP tick and bidask payloads | Python object fields include Python-native `datetime` and Decimal-like values; `.to_dict(raw=True)` is useful when exact raw fields are needed | SSE JSON uses server field names such as `date`, `time`, `total_volume`, `price_chg`, `pct_chg`; Decimal price/amount fields are strings | Same as HTTP/SSE for non-Python languages | Do not copy Python-only field names or types into HTTP clients. Convert string prices to decimal/float in the client language. |
| Continuous futures R1/R2 over HTTP | Python can subscribe by the resolved contract object | For `TXFR1`/`TXFR2`, include `target_code` from `GET /api/v1/data/contracts/TXFR1?security_type=FUT`; regular futures codes do not need it | CLI/HTTP stream paths that build HTTP payloads must include `target_code` for R1/R2 | If HTTP subscribe returns 200 but SSE only emits heartbeats for R1/R2, first check missing or stale `target_code`. This special rule is futures R1/R2 only. |
| Order/deal event stream | Use order callbacks/receivers (`api.set_order_callback`, `api.get_order_event_receiver()`) and `api.subscribe_trade(account)` for production event relay | `POST /api/v1/auth/subscribe_trade` returns `SubscribeTradeOut`; `GET /api/v1/stream/data/order_event` emits `order_event` SSE | `shioaji order events` is an active event stream, not historical records | In production, subscribe per account before opening `order_event`; otherwise expect heartbeat-only. In simulation, subscribe is not required and unsubscribe can return validation error. |
| Stream status | No normal Python equivalent for HTTP connection count | `GET /api/v1/stream/status` returns `ConnectionStatus { active_connections, timestamp, status }` | Diagnostic only if exposed | Use this to diagnose live SSE connection count or unhealthy stream service; it does not prove a symbol is subscribed. |
| Receiver availability | Python receivers are obtained directly by `api.get_*_receiver()` | `GET /api/v1/stream/receivers` returns receiver availability text | Diagnostic only if exposed | This is diagnostic. Use `/stream/status` for live connection count and subscribe/SSE endpoints for actual data flow. |

---

## Python Callbacks 行情回調

### Decorator Syntax 裝飾器語法

```python
from shioaji import TickSTKv1, BidAskSTKv1, TickFOPv1, BidAskFOPv1

# Stock tick 股票 Tick
@api.on_tick_stk_v1()
def on_tick(tick: TickSTKv1):
    print(f"Code: {tick.code}, Close: {tick.close}, Volume: {tick.volume}")

# Stock bidask 股票五檔
@api.on_bidask_stk_v1()
def on_bidask(bidask: BidAskSTKv1):
    print(f"Code: {bidask.code}, Bid: {bidask.bid_price[0]}, Ask: {bidask.ask_price[0]}")

# Futures/options tick 期貨選擇權 Tick
@api.on_tick_fop_v1()
def on_fop_tick(tick: TickFOPv1):
    print(f"Code: {tick.code}, Close: {tick.close}")

# Futures/options bidask 期貨選擇權五檔
@api.on_bidask_fop_v1()
def on_fop_bidask(bidask: BidAskFOPv1):
    print(f"Code: {bidask.code}, Bid: {bidask.bid_price[0]}")

# Stock quote 股票彙總報價
@api.on_quote_stk_v1()
def on_quote_stk(quote):
    print(f"Quote STK: {quote}")

# Futures/options quote 期貨選擇權彙總報價
@api.on_quote_fop_v1()
def on_quote_fop(quote):
    print(f"Quote FOP: {quote}")
```

### Setter Syntax 設定器語法

```python
# Equivalent to decorators 等同於裝飾器
api.set_on_tick_stk_v1_callback(on_tick)
api.set_on_bidask_stk_v1_callback(on_bidask)
api.set_on_tick_fop_v1_callback(on_fop_tick)
api.set_on_bidask_fop_v1_callback(on_fop_bidask)
api.set_on_quote_stk_v1_callback(on_quote_stk)
api.set_on_quote_fop_v1_callback(on_quote_fop)
```

### Clear Callbacks 清除回調

```python
api.clear_on_tick_stk_v1_callback()
api.clear_on_bidask_stk_v1_callback()
api.clear_on_tick_fop_v1_callback()
api.clear_on_bidask_fop_v1_callback()
api.clear_on_quote_stk_v1_callback()
api.clear_on_quote_fop_v1_callback()
```

### Context Binding 綁定上下文

Pass `bind=True` to inject a shared context object as the **first** callback argument:
傳入 `bind=True` 時，共享 context 會成為 callback 的**第一個**參數：

```python
api.set_context({"positions": {}})

@api.on_tick_stk_v1(bind=True)
def on_tick(context, tick):
    context["positions"][tick.code] = tick.close
```

**Note 注意:** Legacy examples may show the compatible 2-argument form `(exchange, data)`. Current bindings auto-detect that form, dispatch it for compatibility, and emit a deprecation warning. For newly generated code, prefer 1-argument callbacks `(data)`. With `bind=True`, prefer `(context, data)` because context is pre-bound as the first argument. The legacy bind form `(context, exchange, data)` also works but emits the same deprecation warning.
舊範例可能出現相容用的雙參數寫法 `(exchange, data)`。目前 binding 會自動偵測並相容 dispatch，但會發出 deprecation warning。新產生的程式碼建議使用單參數 callback `(data)`；使用 `bind=True` 時，建議使用 `(context, data)`，因為 context 會預先綁成第一個參數。舊式 bind 寫法 `(context, exchange, data)` 也可運作，但同樣會有 deprecation warning。

---

## Async Callbacks 非同步回調

For `ShioajiAsync`, all callbacks must be `async def`:
對於 `ShioajiAsync`，所有回調必須是 `async def`：

```python
api = sj.ShioajiAsync()
await api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

@api.on_tick_stk_v1()
async def on_tick(tick):
    print(f"Code: {tick.code}, Close: {tick.close}")

@api.on_bidask_stk_v1()
async def on_bidask(bidask):
    print(f"Code: {bidask.code}, Spread: {bidask.ask_price[0] - bidask.bid_price[0]}")

# Setter syntax also works 設定器語法也可使用
api.set_on_tick_fop_v1_callback(some_async_callback)

# Same clear methods 相同的清除方法
api.clear_on_tick_stk_v1_callback()
```

---

## Python Receivers Python 接收器

Callbacks are the normal Python path. Receivers are lower-level public APIs for consumers that want to pull events themselves. They are Python-only and are not the same as HTTP SSE; HTTP clients should use `/api/v1/stream/data/*`.
Callbacks 是一般 Python 使用路徑。Receivers 是較底層的 public API，給想自行拉取事件的 Python consumer 使用。這是 Python-only，和 HTTP SSE 不同；HTTP client 應使用 `/api/v1/stream/data/*`。

```python
api.subscribe(api.Contracts.Stocks["2330"], quote_type=sj.QuoteType.Tick)

receiver = api.get_tick_stk_v1_receiver()
tick = await receiver.recv()       # async wait
maybe_tick = receiver.try_recv()   # None if no event is ready
```

Available receivers:
可用 receiver：

```python
api.get_tick_stk_v1_receiver()
api.get_bidask_stk_v1_receiver()
api.get_tick_fop_v1_receiver()
api.get_bidask_fop_v1_receiver()
api.get_order_event_receiver()
```

Callback setters prepare the required event handling automatically. Do not ask users to call private `start_*_handler()` helpers; they are not part of the normal Python API surface.
Callback setter 會自動準備需要的事件處理。不要要求使用者直接呼叫 private `start_*_handler()` helper；那些不是正常 Python API surface。

---

## Callback Reference 回調參考

### TickSTKv1 Attributes 股票 Tick 屬性

```python
tick.code              # str: Stock code 股票代碼
tick.datetime          # datetime: Timestamp 時間戳
tick.open              # Decimal: Open price 開盤價
tick.high              # Decimal: High price 最高價
tick.low               # Decimal: Low price 最低價
tick.close             # Decimal: Last price 最新價
tick.avg_price         # Decimal: Average price 均價
tick.volume            # int: Tick volume 單筆成交量
tick.total_volume      # int: Total volume 總成交量
tick.amount            # Decimal: Tick amount 單筆成交金額
tick.total_amount      # Decimal: Total amount 總成交金額
tick.tick_type         # int: 1=Buy, 2=Sell, 0=Unknown
tick.chg_type          # int: Change type 漲跌類型
tick.price_chg         # Decimal: Price change 漲跌
tick.pct_chg           # Decimal: Percent change % 漲跌幅
tick.bid_side_total_vol  # int: Total bid volume 買方總量
tick.ask_side_total_vol  # int: Total ask volume 賣方總量
tick.bid_side_total_cnt  # int: Total bid count 買方筆數
tick.ask_side_total_cnt  # int: Total ask count 賣方筆數
tick.intraday_odd        # bool: True 表示盤中零股流 (`TIC/v1/ODD/...`), 否則 False
```

### BidAskSTKv1 Attributes 股票五檔屬性

```python
bidask.code            # str: Stock code 股票代碼
bidask.datetime        # datetime: Timestamp 時間戳
bidask.bid_price       # List[Decimal]: [買1, 買2, 買3, 買4, 買5]
bidask.bid_volume      # List[int]: [買量1, 買量2, ...]
bidask.ask_price       # List[Decimal]: [賣1, 賣2, 賣3, 賣4, 賣5]
bidask.ask_volume      # List[int]: [賣量1, 賣量2, ...]
bidask.diff_bid_vol    # List[int]: Bid volume changes 買量變化
bidask.diff_ask_vol    # List[int]: Ask volume changes 賣量變化
bidask.intraday_odd    # bool: True 表示盤中零股流 (`QUO/v1/ODD/...`), 否則 False
```

### TickFOPv1 Attributes 期貨選擇權 Tick 屬性

```python
tick.code              # str: Contract code 合約代碼
tick.datetime          # datetime: Timestamp 時間戳
tick.open              # Decimal: Open price 開盤價
tick.high              # Decimal: High price 最高價
tick.low               # Decimal: Low price 最低價
tick.close             # Decimal: Last price 最新價
tick.volume            # int: Tick volume 單筆量
tick.total_volume      # int: Total volume 總量
tick.underlying_price  # Decimal: Underlying price 標的價格
tick.bid_side_total_vol # int: Buy side total volume 買方總量
tick.ask_side_total_vol # int: Sell side total volume 賣方總量
```

### BidAskFOPv1 Attributes 期貨選擇權五檔屬性

```python
bidask.code            # str: Contract code 合約代碼
bidask.datetime        # datetime: Timestamp 時間戳
bidask.bid_price       # List[Decimal]: Bid prices (5 levels)
bidask.bid_volume      # List[int]: Bid volumes (5 levels)
bidask.ask_price       # List[Decimal]: Ask prices (5 levels)
bidask.ask_volume      # List[int]: Ask volumes (5 levels)
```

---

## System Callbacks 系統回調

### set_on_quote_callback 設定報價回調

Legacy quote callback for index tick/bidask data:
指數 tick/bidask 資料的舊式報價回調：

```python
def quote_cb(topic, msg):
    print(f"Topic: {topic}, Message: {msg}")

api.set_on_quote_callback(quote_cb)

# Clear 清除
api.clear_on_quote_callback()
```

### set_contract_event_callback 設定商品檔更新事件回調

`set_contract_event_callback` is a Python-only system callback for `SYS/CONTRACT` update events. It is different from login-time `contracts_cb`: `contracts_cb` notifies that contract files finished loading, while contract event callbacks notify that an upstream contract update event arrived and the client reloaded contracts.
`set_contract_event_callback` 是 Python-only 的 `SYS/CONTRACT` 商品檔更新事件 callback。它和登入時的 `contracts_cb` 不同：`contracts_cb` 通知商品檔下載完成；contract event callback 則通知上游商品檔更新事件到達，且 client 已重新載入商品檔。

```python
def on_contract_event(event):
    print(event.action)
    print(event.security_type)

api.set_contract_event_callback(on_contract_event)

# Clear 清除
api.clear_contract_event_callback()
```

### set_session_down_callback 設定斷線回調

Fires when the session goes down (DownError events):
當連線中斷（DownError 事件）時觸發：

```python
def on_down():
    print("Session is down!")

api.set_session_down_callback(on_down)

# Decorator syntax 裝飾器語法
@api.on_session_down
def on_down():
    print("Session is down!")

# Clear 清除
api.clear_session_down_callback()
```

### Async System Callbacks 非同步系統回調

```python
async def on_down():
    print("Session is down!")

api.set_session_down_callback(on_down)  # Must be async for ShioajiAsync

async def quote_cb(topic, msg):
    print(f"Topic: {topic}")

api.set_on_quote_callback(quote_cb)
```

---

## SSE Streaming (HTTP) SSE 串流

The Shioaji HTTP server provides Server-Sent Events (SSE) for real-time data streaming.
Shioaji HTTP 伺服器透過 Server-Sent Events (SSE) 提供即時資料串流。

### SSE Channels 串流頻道

| Channel 頻道 | SSE Event Name | Description 說明 |
|--------------|----------------|------------------|
| All data 全部資料 | (mixed) | `/api/v1/stream/data` |
| Stock tick 股票逐筆 | `tick_stk` | `/api/v1/stream/data/tick_stk` |
| Stock bidask 股票五檔 | `bidask_stk` | `/api/v1/stream/data/bidask_stk` |
| Futures tick 期貨逐筆 | `tick_fop` | `/api/v1/stream/data/tick_fop` |
| Futures bidask 期貨五檔 | `bidask_fop` | `/api/v1/stream/data/bidask_fop` |
| Stock quote 股票報價 | `quote_stk` | `/api/v1/stream/data/quote_stk` |
| Futures quote 期貨報價 | `quote_fop` | `/api/v1/stream/data/quote_fop` |
| Order events 委託事件 | `order_event` | `/api/v1/stream/data/order_event` |

### SSE Flow SSE 使用流程

Market data and trade events use the same explicit-subscribe pattern:

1. **Subscribe** to each resource you want to receive (POST) 先訂閱每個要接收的資源
2. **Connect** to SSE endpoint (GET) 連接 SSE 端點
3. **Receive** events as JSON in `data:` fields 接收 JSON 格式的事件

```bash
# Market data: subscribe per contract before opening tick/bidask/quote streams
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"STK","exchange":"TSE","code":"2330","quote_type":"Tick"}'

# Futures continuous-month aliases via HTTP, such as TXFR1/TXFR2,
# require target_code from contract lookup. Regular futures codes do not.
# Step 1: look up TXFR1 and read the returned target_code, for example TXFF6.
curl "http://localhost:8080/api/v1/data/contracts/TXFR1?security_type=FUT"

# Step 2: subscribe with both code=TXFR1 and the returned target_code.
# For TXFR1/TXFR2, missing target_code can return 200 but only emit SSE heartbeats.
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"FUT","exchange":"TAIFEX","code":"TXFR1","target_code":"TXFF6","quote_type":"Tick"}'

# Trade events: subscribe per account before opening order_event stream.
# REQUIRED for /stream/data/order_event in production — without it the SSE
# stream only emits heartbeats. Mirrors api.subscribe_trade(account) in Python.
curl -X POST http://localhost:8080/api/v1/auth/subscribe_trade \
  -H "Content-Type: application/json" \
  -d '{"broker_id":"9A95","account_id":"1234567","account_type":"S"}'

# Connect to SSE (all channels) 連接全部頻道
curl -N http://localhost:8080/api/v1/stream/data

# Or connect to a specific channel 或連接特定頻道
curl -N http://localhost:8080/api/v1/stream/data/tick_stk
curl -N http://localhost:8080/api/v1/stream/data/order_event
```

Trade subscriptions stay active across the server's daily client refresh — call `subscribe_trade` once per account per server boot. Use `POST /api/v1/auth/unsubscribe_trade` (same body) to stop receiving events for an account.

In **simulation**, `subscribe_trade` returns a no-op success and `unsubscribe_trade` returns `400`. Paper order events do not require trade-event subscription. You don't need to call either in simulation.

訂閱委託回報需要在打開 `/stream/data/order_event` SSE 之前**先呼叫**一次 `/auth/subscribe_trade`（每帳號一次）；沒有訂閱的話正式環境只會收到 heartbeat。訂閱會跨過 server 每日 client refresh，所以一個 server 開機後對每個帳號訂閱一次即可。**Simulation 模式下不需要呼叫**：`subscribe_trade` 會直接 no-op 成功，`unsubscribe_trade` 會回 400，paper 委託事件不需要 trade-event subscription。

### SSE Event Format SSE 事件格式

```
event: tick_fop
data: {"code":"TXFD6","date":"2026-04-01","time":"18:33:18.084000","open":"33601","close":"33438","high":"33728","low":"33317","volume":1,"total_volume":21748,"tick_type":0,"price_chg":"49","simtrade":false}

event: heartbeat
data: {"type":"heartbeat","timestamp":"2026-03-31T01:00:30Z","connection_id":"42"}

event: order_event
data: {"operation":{"op_type":"New","op_code":"00","op_msg":""},"order":{...},...}
```

> **Important — Decimal fields are JSON strings / Decimal 欄位為 JSON 字串**
>
> Python callback objects and HTTP SSE JSON do not use exactly the same field names. HTTP SSE uses the server JSON names, for example `total_volume`, `total_amount`, `price_chg`, `pct_chg`, `bid_side_total_vol`, and `ask_side_total_vol`.
>
> Price and amount fields (`open`, `close`, `high`, `low`, `amount`, `total_amount`, `avg_price`, `price_chg`, `pct_chg`, `underlying_price`) are serialized as **strings** (e.g., `"close":"33438"`) because the server uses `Decimal` type for precision. Volume fields (`volume`, `total_volume`, `bid_side_total_vol`, `ask_side_total_vol`) are numbers.
>
> This differs from REST API responses (like `/data/snapshots`) where prices are JSON numbers. When parsing SSE data, convert string fields to your language's decimal/float type.
>
> 價格與金額欄位以**字串**傳送（例如 `"close":"33438"`），因為伺服器使用 `Decimal` 型別確保精度。成交量欄位為數字。這與 REST API 回應（如 `/data/snapshots`）不同，後者價格為 JSON 數字。

### Heartbeat 心跳

SSE connections send a heartbeat every **30 seconds** to keep the connection alive.
SSE 連線每 **30 秒** 發送一次心跳以維持連線。

### Connection Status 連線狀態

```bash
# GET /api/v1/stream/status
curl http://localhost:8080/api/v1/stream/status
```

Response:
```json
{
  "active_connections": 3,
  "timestamp": "2026-03-31T01:00:00Z",
  "status": "healthy"
}
```

### JavaScript SSE Client Example

```javascript
const es = new EventSource("http://localhost:8080/api/v1/stream/data/tick_stk");

es.addEventListener("tick_stk", (event) => {
  const tick = JSON.parse(event.data);
  console.log(`${tick.code}: ${tick.close} x ${tick.volume}`);
});

es.addEventListener("heartbeat", (event) => {
  console.log("Heartbeat:", JSON.parse(event.data).timestamp);
});

es.onerror = () => console.log("SSE connection error");
```

---

## Best Practices 最佳實踐

### 1. Rate Limiting 速率限制

```python
# Limit: 50 requests / 5 seconds
# 限制：50 次 / 5 秒

import time

for i, contract in enumerate(contracts):
    api.subscribe(contract, quote_type=sj.QuoteType.Tick)
    if (i + 1) % 50 == 0:
        time.sleep(5)
```

### 2. Handle Disconnections 處理斷線

```python
@api.on_session_down
def on_down():
    print("Session down, reconnecting...")
    # Resubscribe after reconnection 重連後重新訂閱
```

### 3. Memory Management 記憶體管理

```python
from collections import deque

class QuoteBuffer:
    def __init__(self, max_size=10000):
        self.buffer = deque(maxlen=max_size)

    def add(self, tick):
        self.buffer.append({
            "code": tick.code,
            "datetime": tick.datetime,
            "price": float(tick.close),
            "volume": tick.volume,
        })
```

### 4. SSE: Use Specific Channels SSE 使用特定頻道

Connect to specific SSE endpoints (e.g., `/stream/data/tick_stk`) instead of the combined `/stream/data` endpoint to reduce bandwidth.
連接特定 SSE 端點（如 `/stream/data/tick_stk`）而非合併的 `/stream/data` 端點以減少頻寬。

For full HTTP endpoint paths, see [HTTP_API.md](HTTP_API.md).
完整的 HTTP 端點路徑請參見 [HTTP_API.md](HTTP_API.md)。
