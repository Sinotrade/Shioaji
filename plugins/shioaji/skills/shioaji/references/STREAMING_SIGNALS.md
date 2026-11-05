# Market Signals 市場訊號

Market signals are market-wide push alerts from the quote engine: subscribe a **rule + scope** with `api.subscribe_scanner(scanner, *, region, security_type, exchange)`, and any stock in scope that triggers the rule produces an event. One global callback consumes every signal subscription. Without a callback, events default-print.

市場訊號是行情引擎的全市場推送：以 `api.subscribe_scanner(scanner, *, region, security_type, exchange)` 訂閱「規則＋範圍」，範圍內任何觸發規則的個股都會推送事件。所有訊號訂閱共用一個全域 callback；未設 callback 時預設印出。

> NOT `api.scanners(scanner_type=...)` — that is the historical ranking query (`ScannerType`, [MARKET_DATA.md](MARKET_DATA.md)). This file is realtime push.
> 不是 `api.scanners()`（歷史排行查詢，見 [MARKET_DATA.md](MARKET_DATA.md)）；本檔是即時推送。

## Table of Contents 目錄

- [Scope 範圍](#scope-範圍closed-封閉)
- [Rule Matrix 規則矩陣](#rule-matrix-規則矩陣closed-set-封閉集合)
- [Consuming Events 事件消費](#consuming-events-事件消費)
- [Minimal Examples 最小範例](#minimal-examples-最小範例)
- [Attributes Reference 屬性參考](#attributes-reference-屬性參考)
- [Response and Decision Summary 回應與決策摘要](#response-and-decision-summary-回應與決策摘要)

## Scope 範圍（closed 封閉）

`region=Region.TW`, `security_type=SecurityType.Stock`, `exchange=Exchange.TSE|Exchange.OTC` — all keyword-only and required. Taiwan stocks only.
三個 keyword-only 必填參數；目前僅台股股票，交易所 TSE 或 OTC。

## Rule Matrix 規則矩陣（closed set 封閉集合）

| Family | Python factory | Wire id (HTTP) | Trigger 觸發語意 | Event / extra |
|---|---|---|---|---|
| `LimitScanner` | `bid_near_limit_up()` | `bid_near_limit_up` | bid nearing limit up 買方報價接近漲停 | `ScannerSignalEvent` / `LimitScannerExtra` |
| | `bid_touch_limit_up()` | `bid_touch_limit_up` | bid touching limit up 觸及漲停 | 〃 |
| | `limit_up_unlocked()` | `limit_up_unlocked` | limit up unlocked 漲停打開 | 〃 |
| | `ask_near_limit_down()` | `ask_near_limit_down` | ask nearing limit down 接近跌停 | 〃 |
| | `ask_touch_limit_down()` | `ask_touch_limit_down` | ask touching limit down 觸及跌停 | 〃 |
| | `limit_down_unlocked()` | `limit_down_unlocked` | limit down unlocked 跌停打開 | 〃 |
| `PriceMoveScanner` | `trade_surge()` | `trade_price_surge` | >1% and ≥3 ticks within 1s (trade price), 1s cooldown 成交價 1 秒內急漲 | `ScannerSignalEvent` / `PriceMoveExtra` |
| | `trade_drop()` | `trade_price_drop` | same, dropping 急跌 | 〃 |
| | `bid_surge()` | `bid_price_surge` | bid price surging 買方報價急漲 | 〃 |
| | `ask_drop()` | `ask_price_drop` | ask price dropping 賣方報價急跌 | 〃 |
| `VolumeScanner` | `burst()` | `volume_burst` | single trade value > daily threshold, 5s cooldown 單筆成交金額超過當日門檻 | `ScannerSignalEvent` / `VolumeBurstExtra` |
| `StreamScanner` | `Simtrade` (attr, no call) | `"simtrade"` (plain string) | quotes of stocks in simulated matching 試撮行情（不限開收盤，處置股分盤／穩定措施也推） | `ScannerQuoteEvent` (no extra) |
| | `Suspend` (attr, no call) | `"suspend"` | suspended trading 暫停交易 | 〃 |

**Trap 陷阱**: Python factory names ≠ wire ids (`trade_surge()` → `trade_price_surge`). Use the table; do not guess either direction.
Python 工廠名 ≠ wire id，一律查表，不要互猜。

## Consuming Events 事件消費

One global callback for all signal subscriptions: `api.set_on_scanner_callback(cb)` / `@api.on_scanner()` / `api.get_scanner_receiver()`. The callback receives a union — dispatch by event class, then by rule family; match a single rule with `==`:

所有訊號共用一個 callback，收到的是 union，先按事件類別、再按規則家族分派；單一規則用 `==` 比對：

```python
from shioaji import (
    ScannerSignalEvent, ScannerQuoteEvent, ScannerGapEvent,
    LimitScanner, PriceMoveScanner, VolumeScanner,
)

@api.on_scanner()
def scanner_callback(event):
    if isinstance(event, ScannerSignalEvent):
        if isinstance(event.scanner, LimitScanner):
            ...                                   # or: event.scanner == LimitScanner.ask_near_limit_down()
        elif isinstance(event.scanner, PriceMoveScanner):
            ...
        elif isinstance(event.scanner, VolumeScanner):
            ...
    elif isinstance(event, ScannerQuoteEvent):    # StreamScanner quotes
        ...
    elif isinstance(event, ScannerGapEvent):      # dropped-event report after reconnect
        ...
```

- `ScannerGapEvent` (`dropped_count, first_time, last_time, subscriptions`) exists **only on the scanner channel**; other streaming channels have no gap notification.
  gap 通報僅 scanner 頻道有，其他頻道沒有。

```python
# Setter syntax 設定器語法（equivalent 等同）
api.set_on_scanner_callback(scanner_callback)

# Clear 清除
api.clear_on_scanner_callback()

# Receiver 接收器
receiver = api.get_scanner_receiver()
event = await receiver.recv()      # async wait
maybe = receiver.try_recv()        # None if no event is ready
```

Async (`ShioajiAsync`) uses the same names with `async def` callbacks.
Async 同名、callback 改 `async def`。

## Minimal Examples 最小範例

```python
api.subscribe_scanner(
    scanner=sj.PriceMoveScanner.trade_drop(),
    region=sj.Region.TW,
    security_type=sj.SecurityType.Stock,
    exchange=sj.Exchange.TSE,
)
# unsubscribe_scanner takes the same arguments 取消訂閱同參數
```

```bash
# preset rule 規則類
curl -X POST localhost:8080/api/v1/stream/subscribe/scanner -H 'Content-Type: application/json' \
  -d '{"scanner":{"kind":"preset_rule","id":"trade_price_drop"},"region":"TW","security_type":"STK","exchange":"TSE"}'
# status filter 狀態過濾（plain string 字串形式）
curl -X POST localhost:8080/api/v1/stream/subscribe/scanner -H 'Content-Type: application/json' \
  -d '{"scanner":"simtrade","region":"TW","security_type":"STK","exchange":"TSE"}'
curl -N localhost:8080/api/v1/stream/data/scanner
```

## Attributes Reference 屬性參考

### ScannerSignalEvent Attributes 訊號事件屬性

```python
event.scanner          # LimitScanner|PriceMoveScanner|VolumeScanner: 觸發的規則
event.region           # Region: 市場
event.security_type    # SecurityType: 商品類型
event.exchange         # Exchange: 交易所
event.quote            # QuoteSTKv1Core: 觸發當下個股報價快照
event.extra            # LimitScannerExtra|PriceMoveExtra|VolumeBurstExtra: 依規則家族
```

### ScannerQuoteEvent Attributes 狀態過濾事件屬性

```python
event.scanners         # tuple[StreamScanner, ...]: 符合的過濾（可同時多個）
event.region           # Region: 市場
event.security_type    # SecurityType: 商品類型
event.exchange         # Exchange: 交易所
event.quote            # QuoteSTKv1Core: 個股報價（no extra 無 extra）
```

### Extra Attributes 附加資訊屬性

```python
# LimitScannerExtra 漲跌停
extra.previous_best_price  # Optional[Decimal]: 前一次最佳報價（首次觸發為 None）
extra.trigger_price        # Decimal: 觸發訊號的最佳報價
extra.limit_price          # Decimal: 漲跌停價

# PriceMoveExtra 價格急變
extra.reference_time       # str: 比較基準時間
extra.reference_price      # Decimal: 比較基準價格
extra.change_price         # Decimal: 期間價格變動
extra.change_percent       # Decimal: 期間漲跌幅 (%)
extra.tick_change          # int: 期間 tick 變動數
extra.elapsed_ms           # int: 距基準時間毫秒數

# VolumeBurstExtra 爆量
extra.amount               # int: 單筆成交金額 (TWD)
extra.volume               # int: 單筆成交量 (張)
extra.price                # Decimal: 成交價
extra.threshold            # int: 當日門檻 (TWD，server 每日重算)
```

**Trap 陷阱**: `event.quote` is `QuoteSTKv1Core` — wire field names (`amount_sum`, `vol_sum`, `diff_price`, …), **no `exchange` field** (exchange lives on the event), and the class is not declared in the type stub; use `event.quote.code` attribute access or `.to_dict()`, do not rely on stub autocompletion.
`event.quote` 是 `QuoteSTKv1Core`：wire 欄位名、沒有 `exchange`（在 event 層）、stub 未宣告；用屬性存取或 `.to_dict()`，別依賴 stub 補全。

## Response and Decision Summary 回應與決策摘要

| Operation | Python | HTTP | Agent decision |
|---|---|---|---|
| Subscribe signal | `api.subscribe_scanner(...)`; events default-print unless callback/receiver attached | `POST /stream/subscribe/scanner` → `{success, message}` (no `subscription` field) | On error check the rule id against the Rule Matrix and the closed scope (TW/STK/TSE\|OTC). Wire id ≠ factory name is the most common mistake. |
| Consume | one global callback / receiver for all signal subscriptions | `GET /stream/data/scanner` SSE; `event:scanner`; rule events carry `"scanner"`, status filters carry `"scanners":[…]` | Dispatch by event class first. Heartbeat-only outside trading hours is normal. |
| Unsubscribe | same args to `api.unsubscribe_scanner(...)` | same body to `/stream/unsubscribe/scanner` | Treat `success=true` as accepted. |
