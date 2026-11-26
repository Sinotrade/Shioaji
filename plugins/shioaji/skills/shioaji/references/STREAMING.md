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
- [US Quotes 美股行情](#us-quotes-美股行情)
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

stock = api.contracts.get("2330")
future = api.contracts.get("TXFR1")
if stock is None or future is None:
    raise LookupError("quote contract not found")

# Subscribe tick data 訂閱逐筆成交
api.subscribe(
    stock,
    quote_type=sj.QuoteType.Tick,
)

# Subscribe bidask data 訂閱五檔
api.subscribe(
    stock,
    quote_type=sj.QuoteType.BidAsk,
)

# Subscribe futures tick 訂閱期貨 Tick
api.subscribe(
    future,
    quote_type=sj.QuoteType.Tick,
)

# Intraday odd lot 盤中零股 - Tick
api.subscribe(
    stock,
    quote_type=sj.QuoteType.Tick,
    intraday_odd=True,
)

# Intraday odd lot 盤中零股 - BidAsk (五檔)
api.subscribe(
    stock,
    quote_type=sj.QuoteType.BidAsk,
    intraday_odd=True,
)

# Realtime 1-min KBar 即時K棒（stocks only 僅股票；intraday_odd not supported）
api.subscribe(
    stock,
    quote_type=sj.QuoteType.KBar,
)

# Unsubscribe 取消訂閱
api.unsubscribe(
    stock,
    quote_type=sj.QuoteType.Tick,
)
```

### Combo Quote Subscription 組合行情訂閱

Build the combo from two resolved base/info contracts. Do not pass the native
slash topic code yourself.

```python
first = api.contracts.get("TXFL6")
second = api.contracts.get("TXFC7")
if first is None or second is None:
    raise LookupError("combo leg not found")

combo = api.contracts.combo(legs=[first, second])
api.subscribe(combo, quote_type=sj.QuoteType.Tick)
# ... receive the normal FOP callback/receiver payload ...
api.unsubscribe(combo, quote_type=sj.QuoteType.Tick)
```

The two legs must both be TAIFEX futures of the same family. Option combos
have no market data — they can only be sent IOC/FOK and never rest on the
book, so there is nothing to quote; subscribing one raises a validation error.
Shioaji converts this structure to the exchange-native key internally.
The callback `code` is `combo.code`; use that property as the dictionary key
when mapping an event back to its structured contract. See
[COMBO_ORDERS.md](COMBO_ORDERS.md#build-combo-contract-建立組合合約) for the
authoritative encoding and mapping rules.

Index products use the exchange/master contract code directly. All index quote
types subscribe to the same QUO-only topic `QUO/v1/IND/*/{exchange}/{code}`
(e.g. `QUO/v1/IND/*/TSE/IX0001`, where `{exchange}` is the index's real exchange
such as TSE or OTC); there is no index TIC stream.

指數商品直接使用交易所/master 商品代碼。所有指數 quote type 都訂閱同一個
QUO-only topic `QUO/v1/IND/*/{exchange}/{code}`（例如 `QUO/v1/IND/*/TSE/IX0001`，
`{exchange}` 為該指數的真實交易所如 TSE 或 OTC），沒有指數 TIC stream。

```python
index = api.contracts.get("IX0001")
if index is None:
    raise LookupError("index IX0001 not found")
api.subscribe(index, quote_type=sj.QuoteType.Quote)
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

For a combo, both subscribe and unsubscribe use the structured body below:

```json
{
  "contract": {
    "legs": [
      {"security_type":"FUT", "region":"TW", "exchange":"TAIFEX", "code":"TXFL6", "target_code":null},
      {"security_type":"FUT", "region":"TW", "exchange":"TAIFEX", "code":"TXFC7", "target_code":null}
    ],
    "combo_type":"TimeSpread"
  },
  "quote_type": "Tick",
  "intraday_odd": false
}
```

HTTP validates these actionless legs through Contract V2 before building the
native topic. Market-data endpoints reject directed legs containing `action`;
that shape remains only for combo order endpoints. `BidAsk` delivers both
sides. See
[COMBO_ORDERS.md](COMBO_ORDERS.md#native-combo-bidask-meaning) for the native
combo bid/ask meaning, and [HTTP_API.md](HTTP_API.md#managed-combo-contracts)
for the complete Contract V2 discovery-to-SSE workflow.

CLI resolves both legs through Contract V2 before posting this body:

```bash
shioaji data stream --code TXFL6 --combo-with TXFC7 --quote-type tick
```

### Multiple Subscriptions 多重訂閱

```python
contracts = [
    api.contracts.get("2330"),
    api.contracts.get("2317"),
    api.contracts.get("2454"),
]
if any(contract is None for contract in contracts):
    raise LookupError("one or more quote contracts were not found")

for contract in contracts:
    api.subscribe(contract, quote_type=sj.QuoteType.Tick)
```

### Realtime KBar 即時K棒（Stocks 股票）

Regular per-stock streaming: one complete 1-minute bar pushed at each minute close; `time` is the bar's start. Stock contracts only (index/futures/options not yet). NOT historical `api.kbars()` — that is a date-range query in [MARKET_DATA.md](MARKET_DATA.md).

一般證券即時行情的一部分：每分鐘收線推送一根完整 1 分 K，`time` 為該根起始時間。僅支援股票合約（指數／期貨／選擇權未支援）。不是歷史 `api.kbars()`（區間查詢，見 [MARKET_DATA.md](MARKET_DATA.md)）。

```python
api.subscribe(api.contracts.get("2330"), quote_type=sj.QuoteType.KBar)
# consume: default print / set_on_kbar_callback / @api.on_kbar() / get_kbar_receiver()
```

- `intraday_odd` / `version` rejected; CLI `shioaji data stream` does not support KBar. Attributes → [KBar Attributes](#kbar-attributes-即時k棒屬性).
  `intraday_odd`／`version` 一律拒絕；CLI 不支援 KBar。欄位見回調參考。
- HTTP is a **dedicated route** (not the generic `/stream/subscribe`): `POST /api/v1/stream/subscribe/kbars` with `{"stocks":[{"security_type":"STK","exchange":"TSE","code":"2330","target_code":null},…]}` (multi-stock), response `{success, message}` without `subscription`; SSE `GET /api/v1/stream/data/kbar`; unsubscribe same body to `/stream/unsubscribe/kbars`.
  HTTP 走專屬路由（非通用 `/stream/subscribe`），body 的 `stocks` 陣列可一次多檔，回應沒有 `subscription` 欄位。

### US Stock Quotes 美股行情

Since 1.8.0. Same `api.subscribe` / `api.unsubscribe` with a
US contract, but only `QuoteType.Tick` (trimmed: regular-session last-price trades plus extended-hours round-lot trades),
`QuoteType.TickFull` (US only: every trade incl. odd lots) and
`QuoteType.BidAsk`, its own callbacks (`on_tick_stk_us_v1`, `on_bidask_stk_us_v1`,
`on_halt_stk_us_v1`) and a separate halt feed. Full reference: [US Quotes 美股行情](#us-quotes-美股行情).
1.8.0 起提供。用同一個 `api.subscribe` 帶美股商品，但只有 Tick（精簡：正規盤更新最新價的成交，加上盤前盤後與夜盤的整股成交）、TickFull（只限美股，含零股的全部成交）與 BidAsk、走獨立 callback 與獨立的暫停事件。完整說明見 [US Quotes 美股行情](#us-quotes-美股行情)。

### Enriched and Signal Products 即時加值與市場訊號

Enriched index products (calculated index, index/industry contribution) → [STREAMING_ENRICHED.md](STREAMING_ENRICHED.md). Market-wide signal alerts (`subscribe_scanner`) → [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md). The subscription-object API once drafted here (`CalculatedIndexSubscription`, `KBarSubscription`, `QuoteFilter`, …) never shipped — do not generate it.

指數加值產品（自算指數、指數／產業貢獻）見 [STREAMING_ENRICHED.md](STREAMING_ENRICHED.md)；全市場訊號（`subscribe_scanner`）見 [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md)。舊草稿的 subscription 物件 API（`CalculatedIndexSubscription` 等）從未出貨，不要生成。

---

## Streaming Response and Decision Summary 即時串流回應與決策摘要

Use this table before generating client code. Python receives typed callback objects; HTTP, CLI, JavaScript, Go, Rust, C#, C++, and Java receive server JSON/SSE shapes.
產生 client code 前先看這張表。Python 收到 typed callback object；HTTP、CLI、JavaScript、Go、Rust、C#、C++、Java 收到 server JSON/SSE 形狀。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| Subscribe market data | `api.subscribe(contract, quote_type=..., intraday_odd=...)`; normal use relies on callbacks/receivers, not a JSON response | `POST /api/v1/stream/subscribe` returns `SubscriptionResponse { success, message, subscription }` | Stream commands subscribe before opening SSE; `--format json` follows HTTP JSON where available | If `success=false` or the POST errors, do not open SSE as if subscribed. Check contract, `quote_type`, `intraday_odd`, and HTTP body. |
| Subscribe realtime KBar | `api.subscribe(contract, quote_type=sj.QuoteType.KBar)` — stocks only; `intraday_odd`/`version` rejected; default-prints unless a callback/receiver is attached | **Dedicated route** `POST /api/v1/stream/subscribe/kbars` `{"stocks":[<contract>,…]}` returns `{success, message}` **without `subscription`**; SSE `GET /api/v1/stream/data/kbar`; unsubscribe same body to `/stream/unsubscribe/kbars` | `shioaji data stream` does NOT support KBar | Do not send KBar through the generic `/stream/subscribe`, and do not expect a `subscription` field in the response. A quiet channel with a live subscription usually means market closed. |
| Unsubscribe market data | `api.unsubscribe(contract, quote_type=...)` | `POST /api/v1/stream/unsubscribe` returns `SubscriptionResponse { success, message, subscription }` | Stream commands unsubscribe on exit when they created the subscription | Treat `success=true` as accepted. If it errors, report the failed unsubscribe; do not invent a remaining subscription state. |
| Market-data SSE | Python callbacks receive `TickSTKv1`, `BidAskSTKv1`, `TickFOPv1`, `BidAskFOPv1`, quote objects, or receiver values | `GET /api/v1/stream/data/*` is SSE. Each event has `event:` and JSON `data:`; heartbeat events are keep-alive only | CLI stream prints events from the SSE channel after subscribe | Parse `event:` first, then decode `data:` for that channel. A heartbeat means the connection is alive, not that market data arrived. |
| Stock/FOP tick and bidask payloads | Python object fields include Python-native `datetime` and Decimal-like values; `.to_dict(raw=True)` is useful when exact raw fields are needed | SSE JSON uses server field names such as `date`, `time`, `total_volume`, `price_chg`, `pct_chg`; Decimal price/amount fields are strings | Same as HTTP/SSE for non-Python languages | Do not copy Python-only field names or types into HTTP clients. Convert string prices to decimal/float in the client language. |
| Continuous futures R1/R2 over HTTP | Python can subscribe by the resolved contract object | For `TXFR1`/`TXFR2`, include `target_code` from `GET /api/v1/data/contracts/TXFR1?security_type=FUT`; regular futures codes do not need it | CLI/HTTP stream paths that build HTTP payloads must include `target_code` for R1/R2 | If HTTP subscribe returns 200 but SSE only emits heartbeats for R1/R2, first check missing or stale `target_code`. This special rule is futures R1/R2 only. |
| Order/deal event stream | Use order callbacks/receivers (`api.set_order_callback`, `api.get_order_event_receiver()`) and `api.subscribe_trade(account)` for per-account delivery | `POST /api/v1/auth/subscribe_trade` returns `SubscribeTradeOut`; `GET /api/v1/stream/data/order_event` emits `order_event` SSE | `shioaji order events` is an active event stream, not historical records; `shioaji auth subscribe-trade [--account]` / `shioaji auth unsubscribe-trade` manage the per-account trade subscription | Production and simulation both support per-account subscription. Subscribe before opening `order_event`; otherwise expect heartbeat-only. |
| Stream status | No normal Python equivalent for HTTP connection count | `GET /api/v1/stream/status` returns `ConnectionStatus { active_connections, timestamp, status }` | `shioaji server status --streams` includes it as `stream_status` | Use this to diagnose live SSE connection count or unhealthy stream service; it does not prove a symbol is subscribed. |
| Receiver availability | Python receivers are obtained directly by `api.get_*_receiver()` | `GET /api/v1/stream/receivers` returns receiver availability text | `shioaji server status --streams` includes it as `stream_receivers` | This is diagnostic. Use `/stream/status` for live connection count and subscribe/SSE endpoints for actual data flow. |

### CLI Stream Diagnostics CLI 串流診斷

`shioaji server status --streams` appends stream diagnostics to the daemon status by calling `GET /api/v1/stream/receivers` and `GET /api/v1/stream/status` on the running daemon. If the daemon is not running or unhealthy, the stream fields are skipped gracefully.

`shioaji server status --streams` 會呼叫運行中 daemon 的 `GET /api/v1/stream/receivers` 與 `GET /api/v1/stream/status`，把串流診斷附加在 daemon 狀態之後；daemon 未運行時自動略過串流欄位。

```bash
shioaji server status --streams
shioaji server status --streams -f json
# → daemon status + stream_receivers (text) + stream_status { active_connections, timestamp, status }
```

In production, remember the per-account trade subscription before opening the order event stream:
正式環境下，開啟委託回報串流前記得先訂閱帳戶事件:

```bash
shioaji auth subscribe-trade                          # default stock account 預設證券帳戶
shioaji auth subscribe-trade --account 9A95-9816502   # specific account 指定帳戶
shioaji order events                                  # then stream order/deal events
shioaji auth unsubscribe-trade --account 9A95-9816502 # stop receiving 取消訂閱
```

---

## Python Callbacks 行情回調

### Decorator Syntax 裝飾器語法

```python
from shioaji import TickSTKv1, BidAskSTKv1, TickFOPv1, BidAskFOPv1, KBar

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

# Stock realtime KBar 股票即時K棒
@api.on_kbar()
def on_kbar(kbar: KBar):
    print(f"Code: {kbar.code}, Time: {kbar.time}, Close: {kbar.close}")
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
api.set_on_kbar_callback(on_kbar)
```

### Clear Callbacks 清除回調

```python
api.clear_on_tick_stk_v1_callback()
api.clear_on_bidask_stk_v1_callback()
api.clear_on_tick_fop_v1_callback()
api.clear_on_bidask_fop_v1_callback()
api.clear_on_quote_stk_v1_callback()
api.clear_on_quote_fop_v1_callback()
api.clear_on_kbar_callback()
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

# Realtime KBar has the same async forms 即時K棒同樣有 async 版本
@api.on_kbar()
async def on_kbar(kbar):
    print(f"Code: {kbar.code}, Close: {kbar.close}")
```

> **Performance (Python only) 效能（限 Python）**: for high-throughput streaming with `ShioajiAsync`, run it on uvloop for a faster event loop. See [PREPARE.md → ShioajiAsync](PREPARE.md#shioajiasync-async-異步).
> 高吞吐串流使用 `ShioajiAsync` 時，建議搭配 uvloop 取得更快的 event loop。見 [PREPARE.md → ShioajiAsync](PREPARE.md#shioajiasync-async-異步)。

---

## Python Receivers Python 接收器

Callbacks are the normal Python path. Receivers are lower-level public APIs for consumers that want to pull events themselves. They are Python-only and are not the same as HTTP SSE; HTTP clients should use `/api/v1/stream/data/*`.
Callbacks 是一般 Python 使用路徑。Receivers 是較底層的 public API，給想自行拉取事件的 Python consumer 使用。這是 Python-only，和 HTTP SSE 不同；HTTP client 應使用 `/api/v1/stream/data/*`。

```python
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")
api.subscribe(contract, quote_type=sj.QuoteType.Tick)

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
api.get_kbar_receiver()
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

### KBar Attributes 即時K棒屬性

```python
kbar.code              # str: Stock code 股票代碼
kbar.date              # str: Date 日期 "YYYY/MM/DD"
kbar.time              # str: Bar start time 該根起始時間 "HH:MM:SS.ffffff"
kbar.open              # float: Open price 開盤價
kbar.high              # float: High price 最高價
kbar.low               # float: Low price 最低價
kbar.close             # float: Close price 收盤價
kbar.volume            # int: Volume 成交量 (張)
kbar.amount            # int: Turnover 成交金額 (NTD)
kbar.tick_count        # int: Number of trades 成交筆數
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

### QuoteIdxV1 Attributes 指數報價屬性

Only the standard fields are guaranteed. Fields marked `broad-market only` are
present only for broad-market indices (e.g. TAIEX `IX0001`); a regular index
such as `EMP88` carries only the standard fields, with the rest `None`.
`repr()` shows a summary: `code, date, time, close, high, low`.
只有標準欄位保證存在；標記 `broad-market only` 的欄位僅大盤指數（如加權指數
`IX0001`）才有，一般指數（如 `EMP88`）僅標準欄位、其餘為 `None`。

```python
# Standard fields 標準欄位（所有指數皆有）
quote.code             # str: Index code 指數代碼
quote.exchange         # Exchange: Exchange 交易所
quote.date             # date: Date 日期
quote.time             # time: Time 時間
quote.datetime         # datetime: Timestamp 時間戳
quote.reference        # Decimal: Previous close 昨收
quote.open             # Decimal: Open 今開
quote.high             # Decimal: High 今高
quote.low              # Decimal: Low 今低
quote.close            # Decimal: Latest index value 最新指數

# Derived fields 衍生欄位
quote.amount_sum       # Decimal: Cumulative turnover 累計成交金額(元)
quote.amount           # Decimal: Turnover 成交金額(元)
quote.volume           # int: Volume 成交股數(張)
quote.vol_sum          # int: Cumulative volume 累計成交股數(張)
quote.count            # int: Cumulative trade count 累計成交筆數
quote.count_sum        # int: Cumulative trade count 累計成交筆數
quote.prev_date        # date: Previous trading day 前一個交易日
quote.prev_amount_sum  # Decimal: Previous-day total turnover 前交易日總額(元)

# Up/down counts 漲跌家數（商品數）
quote.no_trade         # int: Not traded 未成交
quote.limit_up_count   # int: Limit up 漲停
quote.raise_count      # int: Up 漲
quote.flat_count       # int: Unchanged 平
quote.fall_count       # int: Down 跌
quote.limit_down_count # int: Limit down 跌停

# Trade statistics 成交統計（broad-market only 僅大盤）
quote.fund_amount      # Decimal: Fund turnover 基金成交總額(元)
quote.fund_volume      # int: Fund volume 基金成交總股(張)
quote.fund_count       # int: Fund trade count 基金成交總筆數
quote.stock_amount     # Decimal: Stock turnover 股票成交總額(元)
quote.stock_volume     # int: Stock volume 股票成交總張數
quote.stock_count      # int: Stock trade count 股票成交總筆數
quote.bull_amount      # Decimal: Call warrant turnover 認購權證成交總額(元)
quote.bull_volume      # int: Call warrant volume 認購權證成交總張數
quote.bull_count       # int: Call warrant trade count 認購權證成交總筆數
quote.bear_amount      # Decimal: Put warrant turnover 認售權證成交總額(元)
quote.bear_volume      # int: Put warrant volume 認售權證成交總張數
quote.bear_count       # int: Put warrant trade count 認售權證成交總筆數
quote.tib_amount       # Decimal: Innovation board turnover 創新板成交總額(元)
quote.tib_volume       # int: Innovation board volume 創新板成交總張數
quote.tib_count        # int: Innovation board trade count 創新板成交總筆數
quote.fixed_amount     # Decimal: After-hours fixed-price turnover 盤後定價成交總額(元)
quote.fixed_volume     # int: After-hours fixed-price volume 盤後定價成交總張數
quote.fixed_count      # int: After-hours fixed-price trade count 盤後定價成交筆數

# Estimate 預估量（broad-market only 僅大盤）
quote.estimate_amount_sum  # Decimal: Estimated closing turnover 預估收盤總額(元)
```

---

## US Quotes 美股行情

> **1.8.0.** US quotes ship in 1.8.0.
> **1.8.0 起提供。**

US quotes come from one feed per exchange (`NASDAQ`, `NYSE`, `BATS` or `TXSE`,
the contract's base exchange). Three quote types exist for US stocks:

| `quote_type` | Topic | What arrives |
|---|---|---|
| `QuoteType.Tick` (`"tick"`, default) | `IS/v1/TICL/{exchange}/{code}` | Trimmed trades: regular-session trades that update last price, high/low and inner/outer volume (`updates_last=True`), plus pre-market, after-hours and overnight round-lot trades at a valid price (`updates_last=False`) |
| `QuoteType.TickFull` (`"tick_full"`, US only) | `IS/v1/TIC/{exchange}/{code}` | Every trade: odd lots, special-condition and volume-only trades included |
| `QuoteType.BidAsk` (`"bid_ask"`) | `IS/v1/QUO/{exchange}/{code}` | Best bid/ask, one level |

`QuoteType.Quote` raises `US quotes support Tick, TickFull and BidAsk only`,
and `intraday_odd=True` raises (odd-lot trades are on `TickFull` with
`odd_lot=True`). US events use their own callbacks and never reach the Taiwan
`on_tick_stk_v1` / `on_bidask_stk_v1`.
美股每個交易所一條。`QuoteType.Tick`（預設）訂精簡成交 `IS/v1/TICL/...`：正規盤會更新最新價、高低與內外盤的成交，加上盤前、盤後、夜盤的整股有效價成交（`updates_last=False`）；`QuoteType.TickFull`（`"tick_full"`，只限美股）訂完整成交 `IS/v1/TIC/...`：另含零股、特殊條件與只更新量的成交；`QuoteType.BidAsk` 訂最佳一檔 `IS/v1/QUO/...`。`QuoteType.Quote` 與 `intraday_odd=True` 會報錯。美股事件走獨立 callback，不會進台股 callback。

**Tick vs TickFull (US stocks only) 美股 Tick 與 TickFull 差異**

- `Tick` is about 20% of the `TickFull` message count for hot names (most US
  trades are odd lots). Odd-lot, pre/post-market and volume-only trades are
  left out, so `serial_num` **skips**: only check that it increases, never use
  it for gap detection. Cumulative fields are still complete: `total_volume`
  and `total_amount` already include the odd lots you did not receive, and
  `close`, high/low and the inner/outer totals match `TickFull`.
  `Tick` 在熱門股約只有 `TickFull` 的兩成訊息量（美股成交多數是零股）。零股、盤前盤後、只更新量的成交不會送，所以 `serial_num` 會跳號，只能確認遞增，不可拿來偵測缺號；`total_volume`、`total_amount` 等累計值仍完整（已含沒收到的零股量），`close`、高低、內外盤累計與 `TickFull` 相同。
- `TickFull` delivers every trade. `serial_num` is one per-symbol sequence
  shared by Tick and BidAsk (resets daily), so it is contiguous only across
  `TickFull` and `BidAsk` together. Use `TickFull` when you need each odd lot
  or extended-hours print.
  `TickFull` 送每一筆成交。`serial_num` 是每檔 Tick 與 BidAsk 共用的流水號（每日歸零），同時訂 `TickFull` 與 `BidAsk` 合起來才連號；需要每筆零股或盤前盤後成交時才用。
- Both use the same `UsTick` type and the same `on_tick_stk_us_v1` callback (HTTP:
  the same `tick_stk_us` SSE event). Subscribing **both** for one contract
  delivers the trades that are on both streams **twice**; the SDK does not
  de-duplicate, and the order between the two streams is not guaranteed.
  Pick one per contract.
  兩者都是 `UsTick`、同一個 `on_tick_stk_us_v1` callback（HTTP 同為 `tick_stk_us` 事件）。同一檔兩個都訂，重疊的成交會收到兩次，SDK 不去重，兩條之間的先後也不保證；每檔請擇一。
- Taiwan contracts are unaffected: `QuoteType.Tick` is unchanged, and
  `QuoteType.TickFull` on a Taiwan contract raises
  `QuoteType.TickFull (tick_full) is only available for US stocks`.
  台股不受影響：`QuoteType.Tick` 照舊；台股用 `QuoteType.TickFull` 會報錯。

```python
import shioaji as sj

api = sj.Shioaji()  # production: US quotes are not on simulation
api.login(api_key="...", secret_key="...")
aapl = api.contracts.get("AAPL", region="US")  # base exchange from the contract

@api.on_tick_stk_us_v1()
def on_tick_stk_us_v1(tick: sj.UsTick):
    if tick.stale:                    # never act on a stale/delayed quote as realtime
        return
    print(tick.code, tick.price, tick.volume, tick.session, tick.odd_lot)

@api.on_bidask_stk_us_v1()
def on_bidask_stk_us_v1(quote: sj.UsBidAsk):
    print(quote.code, quote.bid_price[0], quote.ask_price[0], quote.freshness.status)

api.subscribe(aapl, quote_type=sj.QuoteType.Tick)        # trimmed: last-price trades + extended-hours round lots
# api.subscribe(aapl, quote_type=sj.QuoteType.TickFull) # every trade incl. odd lots (pick one)
api.subscribe(aapl, quote_type=sj.QuoteType.BidAsk)
# api.unsubscribe(aapl, quote_type=sj.QuoteType.Tick)
```

- Setter form: `set_on_tick_stk_us_v1_callback` / `set_on_bidask_stk_us_v1_callback` /
  `set_on_halt_stk_us_v1_callback` and `clear_on_tick_stk_us_v1_callback` /
  `clear_on_bidask_stk_us_v1_callback` / `clear_on_halt_stk_us_v1_callback`; all take
  `bind=False` like the Taiwan callbacks.
- `ShioajiAsync`: same names with `async def` callbacks; `await api.subscribe(...)`,
  `await api.subscribe_halt_stk_us()`, `await api.unsubscribe_halt_stk_us()`.
  `api.us_tradable(...)` / `api.us_halts()` stay synchronous reads of the local halt book.
  `ShioajiAsync` 名稱相同，callback 用 `async def`；`us_tradable`／`us_halts` 是同步讀本地 halt book。
- There is no US receiver (`get_*_receiver`); use the callbacks.
- Packed messages: under bursts the feed may pack several ticks (or bid/asks)
  of one topic into a single message. From 1.8.0 the SDK unpacks them
  transparently: callbacks and SSE events still get one `UsTick` / `UsBidAsk`
  each, in order, so nothing changes for users. Only when decoding raw
  payloads yourself (e.g. a recorded feed), use
  `sj.UsTick.from_msgpack_batch(data, topic, receive_ts=None)` /
  `sj.UsBidAsk.from_msgpack_batch(...)`, which accept both shapes and return a
  list; `from_msgpack` accepts a single payload only.
  打包訊息：行情量大時，同一 topic 的多筆 Tick／BidAsk 可能包成一則送出。1.8.0 起 SDK 自動拆開，callback 與 SSE 仍是一筆一筆、照順序，使用者不用改任何東西。自己解原始 payload（例如錄下來的資料）時改用 `from_msgpack_batch`，單筆與打包都收、回傳 list；`from_msgpack` 只收單筆。
- HTTP: `POST /api/v1/stream/subscribe` with a US exchange
  (`{"security_type":"STK","exchange":"NASDAQ","code":"AAPL","quote_type":"Tick"}`,
  or `"quote_type":"TickFull"` for every trade);
  events arrive as `tick_stk_us` / `bidask_stk_us` on `/api/v1/stream/data` or the
  dedicated `/api/v1/stream/data/tick_stk_us` and `/api/v1/stream/data/bidask_stk_us`.
  Unsubscribe with the same `quote_type`: `Tick` and `TickFull` are separate subscriptions.

### UsTick fields 美股成交欄位

`TickFull` publishes every trade — regular lots, odd lots, pre-market/after-hours
and special-condition trades — so filter on the flags instead of assuming each
tick moves the last price. `Tick` (trimmed) carries regular-session `updates_last=True` trades plus
pre-market, after-hours and overnight round-lot trades at a valid price; those
extended-hours trades have `updates_last=False` and leave `close`/`high`/`low` at
their regular-session values, so split by `session`, read the trade price from
`price` and extended-hours high/low from `ext_high`/`ext_low`. Same fields.
`TickFull` 每筆成交都會發（整股、碎股、盤前盤後、特殊條件），請依旗標判斷，不要假設每筆都更新最新價；`Tick`（精簡）只發 `updates_last=True` 的成交，欄位相同。

| Field 欄位 | Meaning 說明 |
|---|---|
| `price`, `volume` | This trade's price and shares 這筆成交的價格、股數 |
| `close` | Latest last-eligible **regular-session** price; only moves when `updates_last=True` 正規盤最新可更新成交價 |
| `open`, `high`, `low`, `price_chg`, `pct_chg`, `chg_type` | Regular-session state; change is vs the previous trading day's official close 正規盤狀態；漲跌以前一交易日官方收盤為基準 |
| `updates_last` | `True` if this trade updates last/high/low 此筆是否帶動最新價與高低 |
| `odd_lot` | Odd-lot trade (below a round lot); never updates last 碎股，不帶動最新價 |
| `trade_cond`, `ext_trade_cond` | Raw trade condition codes (CFAPI 2500 / 1021) 原始條件碼 |
| `session` | `UsTradingSession.PreMarket` (1), `Regular` (2), `AfterHours` (3), `Overnight` (4, 21:00-04:00 ET, from around 2026-12-06 約 2026-12-06 起的夜盤; its trades after 20:00 ET belong to the next trade date 美東 20:00 後的成交歸下一交易日), `Unknown` (0) 盤別 |
| `ext_close`, `ext_high`, `ext_low` | Current pre-market, after-hours or overnight last/high/low; `None` during regular session 盤前／盤後／夜盤那組最新價與高低，正規盤為 None |
| `amount`, `total_amount` | Decimal dollars (not rounded) 金額為 Decimal，不取整 |
| `total_volume` | Exchange cumulative volume incl. odd lots 交易所累計量（含碎股） |
| `bid_side_total_*`, `ask_side_total_*` | Counted on `updates_last` trades only; reset daily 只累計可更新成交，每日歸零 |
| `datetime`, `exchange_datetime` | tz-aware UTC `datetime` (raw epoch microseconds in `*_us`) UTC 時間 |
| `serial_num` | Per-symbol sequence shared with BidAsk; resets daily. Contiguous only across `TickFull` + `BidAsk` together; on `Tick` it skips (only check it increases) 每檔流水號，與 BidAsk 共用；`TickFull` 加 `BidAsk` 合起來才連號，`Tick` 會跳號 |

Prices that have no value yet are `None` (bid/ask levels use `0`).
尚無值的價格為 `None`（買賣價以 `0` 表示空檔）。

### Trading status and halts 交易狀態與暫停

Halts are **not** on the tick or bid/ask streams. Subscribe to the US halt feed
(one topic for every US stock, exchange and market-wide event) and ask the SDK
whether a symbol can trade; a stock is tradable only when the whole market, its
exchange and the stock itself are all not halted.
暫停事件不在 Tick／BidAsk 裡。請訂閱美股暫停事件（單一 topic，含個股、交易所、全市場），再向 SDK 查某檔是否可交易：全市場、交易所、個股三層都沒有暫停才算可交易。

```python
api.subscribe_halt_stk_us()                      # topic IS/v1/HALT/US

@api.on_halt_stk_us_v1()
def on_halt_stk_us_v1(halt: sj.UsHalt):
    print(halt.scope, halt.exchange, halt.code, halt.is_halted, halt.halt_reason)

api.us_tradable(aapl)    # False while market, NASDAQ or AAPL is halted
api.us_halts()           # List[UsHalt]: market-wide, then exchanges, then symbols
api.unsubscribe_halt_stk_us()  # also clears the halt book
```

`UsHalt.is_halted` is `True` when `tradable_status` is 2/3 or `instr_status` is
20/27. Before any halt event arrives, `us_tradable` returns `True`.
`is_halted` 在 `tradable_status` 為 2／3 或 `instr_status` 為 20／27 時為 True；尚未收到任何事件前 `us_tradable` 回 True。

Async clients use the same names (`await api.subscribe_halt_stk_us()`, `on_halt_stk_us_v1`,
`set_on_halt_stk_us_v1_callback`, `clear_on_halt_stk_us_v1_callback`). HTTP:
`POST /api/v1/stream/subscribe/halt_stk_us` (and `/unsubscribe/halt_stk_us`); events
arrive as `halt_stk_us` on `/api/v1/stream/data` or `/api/v1/stream/data/halt_stk_us`;
`GET /api/v1/stream/us_tradable?exchange=NASDAQ&code=AAPL` and
`GET /api/v1/stream/us_halts` read the same state as plain JSON:
`us_halts` answers `{subscribed, last_seq, gaps, ignored, halts}` (`gaps` counts
halt `seq` jumps, i.e. events possibly missed) and `us_tradable` answers
`{exchange, code, tradable, subscribed, last_seq}`. With `subscribed: false`,
`tradable` is always `true` and means nothing; subscribe first.
`us_tradable` 回 `subscribed: false` 時 `tradable` 一律為 true、沒有意義，要先訂閱暫停事件。

| Field 欄位 | Values 值 |
|---|---|
| `scope` | `UsHaltScope.Symbol` 個股, `Market` 全市場; `Exchange` 交易所 is reserved and not sent yet (exchange halts arrive per symbol) 交易所層級保留、目前不發，交易所暫停以逐檔送出 |
| `exchange`, `code` | Exchange for symbol/exchange scope; `code` only for symbol scope 交易所；個股才有代碼 |
| `tradable_status` (1708) | `1` normal 正常; `2` halted 暫停 and `3` suspended 停止 both mean not tradable (LULD volatility pauses arrive as `3`) 2 與 3 都算暫停（LULD 波動暫停是 3）; `0` not received yet, treated as tradable 尚未收到、視為正常 |
| `halt_reason` (1012) | `0` none 無; `4` news pending / `5` news released 新聞; `43` LULD pause 漲跌幅暫停; `47`/`48`/`49` market-wide circuit breaker level 1/2/3 全市場熔斷; `19`–`24` resumptions 恢復 |
| `instr_status` (705) | `20` market-wide paused 全市場暫停, `27` halted 暫停交易, `21` quotes resumed 恢復報價, `24` trading resumed 恢復交易, `0` none |
| `market_phase` (1709) | `1` closed 收盤, `2` pre-market 盤前, `4` regular 正規盤, `10` after-hours 盤後, `0` unknown |
| `session`, `seq` | Same session enum as quotes; `seq` is this feed's own sequence 盤別；本 topic 流水號 |

US stocks can halt intraday (LULD pauses, news, regulatory halts, market-wide
circuit breakers). The SDK only knows events received since `subscribe_halt_stk_us()`;
there is no query for halts that started before subscribing, so a newly
connected client must not read "no halt seen" as tradable. When telling a user
a stock cannot trade, include `halt_reason`.
美股盤中會暫停（LULD、新聞、監管、熔斷）。SDK 只知道訂閱之後收到的事件，剛連上時「沒看到暫停」不等於可交易；向使用者說明時附上 `halt_reason`。

Tick and bid/ask still carry the raw `tradable_status` and `market_phase` of the
symbol; prefer `session` for the trading session. `UsBidAsk.quote_cond` (2003)
is `0` normal, `43` crossed (bid above ask), `54` locked (bid equals ask); a
crossed or locked quote is a real market state, not a data error.
Tick／BidAsk 仍帶個股的 `tradable_status`、`market_phase` 原始值；盤別優先用 `session`。`quote_cond` 交叉、鎖定是市場真實狀態，不是資料錯誤。

### Freshness 新鮮度

Every `UsTick` / `UsBidAsk` has `freshness` (`QuoteFreshness`), stamped when the
client receives the message. Agents must check it before treating a quote as
realtime.
每筆美股行情都帶 `freshness`，在 client 收到時計算；agent 使用前必須先檢查。

| Field 欄位 | Meaning 說明 |
|---|---|
| `source_ts` | Exchange time `exchange_datetime` when present, otherwise `datetime` (when the data vendor received it); epoch µs UTC 來源時間（優先用交易所時間） |
| `receive_ts` | Local receive time, epoch µs UTC 本機收到時間 |
| `age_us` / `age` | Transport delay `receive_ts - source_ts` (µs / seconds); negative = source clock ahead 傳輸延遲 |
| `stale_after_us` | Threshold used 判斷門檻 |
| `feed` | `"Realtime"` or `"Delayed"` 來源類型 |
| `status` | `FreshnessStatus.Realtime`, `Stale`, or `Delayed` |
| `stale` | `True` unless `status == Realtime` 非即時即為 True |

Policy 規則:
- `Realtime` only when the feed is realtime **and** the transport delay
  (`age`) is within the threshold.
- `Stale`: realtime feed but the delay exceeds the threshold, or no source time.
- Staleness measures **transport delay only**, never the time since the previous
  trade. Illiquid symbols, warrants and pre/after-hours sessions can go minutes
  between trades and are still realtime; a long gap between messages is not
  stale. 只看傳輸延遲，不看距離上一筆多久；冷門股、盤前盤後幾分鐘才一筆仍是即時。
- `Delayed`: the feed itself is delayed (any path other than the realtime
  `IS/v1` root); **never** reported as realtime, whatever the age.
- Threshold default **3000 ms**; override with env `SJ_US_QUOTE_STALE_AFTER_MS`
  or `sj.set_us_quote_stale_after_ms(ms)` (`sj.get_us_quote_stale_after_ms()`).
- HTTP/SSE JSON carries the same object: `"freshness": {"source_ts", "receive_ts",
  "age_us", "stale_after_us", "feed", "status", "stale"}`; `session` is a string
  (`"PreMarket"`, `"Regular"`, `"AfterHours"`, `"Overnight"`, `"Unknown"`) and decimals are strings.

When answering a user about a US price, say how old it is and whether it is
realtime; if `stale` is true, say the quote is stale/delayed rather than quoting
it as the current price.
回答美股價格時要說明資料時間與是否即時；`stale` 為 True 時要明講是延遲／過時資料。

---

## System Callbacks 系統回調

### Typed index quote callback 型別化指數報價回調

Index quotes use the typed `QuoteIdxV1` callback. The generic `on_quote` /
`set_on_quote_callback` API has been removed. HTTP clients use the `quote_idx`
SSE channel.
指數報價使用 typed `QuoteIdxV1` callback。generic `on_quote` /
`set_on_quote_callback` API 已移除；HTTP client 使用 `quote_idx` SSE channel。

```python
def quote_idx_cb(quote):
    print(quote.code, quote.close)

api.set_on_quote_idx_v1_callback(quote_idx_cb)

# Decorator syntax 裝飾器語法
@api.on_quote_idx_v1()
def quote_idx_cb(quote):
    print(quote.code, quote.close)

# Clear 清除
api.clear_on_quote_idx_v1_callback()
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

async def quote_idx_cb(quote):
    print(quote.code, quote.close)

api.set_on_quote_idx_v1_callback(quote_idx_cb)
```

---

## SSE Streaming (HTTP) SSE 串流

The Shioaji HTTP server provides Server-Sent Events (SSE) for real-time data streaming.
Shioaji HTTP 伺服器透過 Server-Sent Events (SSE) 提供即時資料串流。

### SSE Channels 串流頻道

| Channel 頻道 | SSE Event Name | Description 說明 |
|--------------|----------------|------------------|
| All data 全部資料 | named events below plus Contract V2, enriched data, scanner, and heartbeat | `/api/v1/stream/data` |
| Stock tick 股票逐筆 | `tick_stk` | `/api/v1/stream/data/tick_stk` |
| Stock bidask 股票五檔 | `bidask_stk` | `/api/v1/stream/data/bidask_stk` |
| Futures tick 期貨逐筆 | `tick_fop` | `/api/v1/stream/data/tick_fop` |
| Futures bidask 期貨五檔 | `bidask_fop` | `/api/v1/stream/data/bidask_fop` |
| Stock quote 股票報價 | `quote_stk` | `/api/v1/stream/data/quote_stk` |
| Futures quote 期貨報價 | `quote_fop` | `/api/v1/stream/data/quote_fop` |
| Index quote 指數報價 | `quote_idx` | `/api/v1/stream/data/quote_idx` |
| Stock realtime KBar 股票即時K棒 | `kbar` | `/api/v1/stream/data/kbar` |
| Calculated index 自算指數 | `calculated_index` | `/api/v1/stream/data/calculated_index` |
| Index contribution 指數貢獻 | `index_contribution` | `/api/v1/stream/data/index_contribution` |
| Industry contribution 產業貢獻 | `industry_contribution` | `/api/v1/stream/data/industry_contribution` |
| Market signals 市場訊號 | `scanner` | `/api/v1/stream/data/scanner` |
| Order events 委託事件 | `order_event` | `/api/v1/stream/data/order_event` |
| Contract V2 changes 商品檔異動 | `contract_event` | `/api/v1/stream/data/contract_event` |

Choose the aggregate endpoint when one client needs several event families:
it carries all named events with one heartbeat and counts as one SSE
connection. Choose a dedicated endpoint when the client needs only one family
or requires an independent lifecycle for that stream. The subscription POSTs
do not change: generic quotes, KBar, enriched data, scanner, and production
trade events still use their respective subscribe endpoints.

The aggregate endpoint accepts optional `region` and `security_type` query
parameters, but they filter `contract_event` only. Other event families on the
same connection remain unfiltered. Derived broadcast loss is observable as a
named `<event_name>_gap` event with a dropped count; reconnect or gap handlers
should reconcile snapshot-based state through REST.

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

# Index: use the exchange/master code. Tick/BidAsk/Quote all map to QUO/v1/IND.
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"IND","exchange":"TSE","code":"IX0001","quote_type":"Quote"}'

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
# REQUIRED for /stream/data/order_event in production and simulation — without it the SSE
# stream only emits heartbeats. Mirrors api.subscribe_trade(account) in Python.
curl -X POST http://localhost:8080/api/v1/auth/subscribe_trade \
  -H "Content-Type: application/json" \
  -d '{"broker_id":"9A95","account_id":"1234567","account_type":"S"}'

# Connect to SSE (all channels). These filters affect contract_event only.
curl -N "http://localhost:8080/api/v1/stream/data?region=TW&security_type=STK"

# Or connect to a specific channel 或連接特定頻道
curl -N http://localhost:8080/api/v1/stream/data/tick_stk
curl -N http://localhost:8080/api/v1/stream/data/quote_idx
curl -N http://localhost:8080/api/v1/stream/data/order_event
```

Production and simulation both support `subscribe_trade` and `unsubscribe_trade`. Call `subscribe_trade` after login for each account before consuming `order_event`; success starts active reports for that account. Use `POST /api/v1/auth/unsubscribe_trade` (same body) to stop them.

正式環境與測試環境都支援 `subscribe_trade` 與 `unsubscribe_trade`。登入後，在打開 `/stream/data/order_event` SSE 前先對每個帳戶呼叫 `/auth/subscribe_trade`；成功後開始接收該帳戶的主動回報，未成功訂閱時只會收到 heartbeat。呼叫 `/auth/unsubscribe_trade` 成功後停止接收該帳戶的回報。

### SSE Event Format SSE 事件格式

```
event: tick_fop
data: {"code":"TXFD6","date":"2026-04-01","time":"18:33:18.084000","open":"33601","close":"33438","high":"33728","low":"33317","volume":1,"total_volume":21748,"tick_type":0,"price_chg":"49","simtrade":false}

event: heartbeat
data: {"type":"heartbeat","timestamp":"2026-03-31T01:00:30Z","connection_id":"42"}

event: order_event
data: {"operation":{"op_type":"New","op_code":"00","op_msg":""},"order":{...},...}

event: quote_idx
data: {"exchange":"TSE","code":"IX0001","Date":"2026-07-14","Time":"09:00:01","Reference":"...","Open":"...","High":"...","Low":"...","Close":"..."}

event: calculated_index_gap
data: {"type":"lagged","dropped":3}
```

Index SSE preserves the upstream typed index field names (`Date`, `Time`,
`Reference`, `Open`, `High`, `Low`, `Close`, and optional fields) and adds
lowercase `exchange` and `code` identity fields parsed from the Solace topic.

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
const es = new EventSource("http://localhost:8080/api/v1/stream/data?region=TW");

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
