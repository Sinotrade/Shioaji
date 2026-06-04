# Market Data 市場資料

This document covers historical data, snapshots, daily quotes, credit enquiries, short stock sources, scanners, and disposition/attention stocks in Shioaji.
本文件說明 Shioaji 中的歷史資料查詢、快照、每日行情、資券餘額查詢、券源查詢、掃描器排行及處置/注意股。

Use [MIGRATION.md](MIGRATION.md) when old code imports enums from submodules. This file owns `Snapshot`, `Ticks`, `KBars`, scanner, and regulatory response handling. Python examples below use Python wrapper objects; HTTP/CLI clients must use the HTTP/CLI response notes in this file and fetch `/openapi.json` only when exact installed-server fields are required.

---

## Market Data Response and Decision Summary 行情回應與決策摘要

Use this table before writing parsers or deciding why a market-data response is empty. Do not infer HTTP/CLI fields from Python wrapper attributes.

| Operation | Python return | HTTP response | CLI output | Agent decision |
|---|---|---|---|---|
| Snapshots | `List[Snapshot]`; Python objects expose `ts` | `Vec<Snapshot>` JSON with `datetime` | `shioaji data snapshots --format json` follows HTTP JSON; default output may be formatted | Empty array means no snapshots returned. Do not use Python `ts` in JS/Go/Rust/C#/C++/Java clients. |
| Historical ticks | `Ticks` with `ts`, `close`, `volume`, bid/ask vectors | `Ticks` JSON with `datetime` vector | JSON follows HTTP `Ticks`; non-JSON formats may transpose to rows | Empty response: check `GET /api/v1/auth/usage` first for traffic quota, then date range, contract, trading day, and query parameters. |
| Historical K-bars | `KBars` with `ts`, `Open`, `High`, `Low`, `Close`, `Volume`, `Amount` vectors | `KBars` JSON with `datetime`, `Open`, `High`, `Low`, `Close`, `Volume`, `Amount` vectors | JSON follows HTTP `KBars`; non-JSON formats may transpose to rows | Date/time arrays are column-oriented, not row objects. Empty response follows the same quota/date/contract checks as ticks. |
| Daily quotes | `DailyQuotes`; Python date values are `datetime.date` | `DailyQuotes` JSON | CLI output may be JSON or formatted | Python `date=` accepts `datetime.date` / `datetime.datetime`, not strings. Empty fields usually mean no data for the date/exclude combination. |
| Credit enquiry | `List[CreditEnquire]` | `Vec<CreditEnquire>` JSON | CLI output may be JSON or formatted | Empty array can mean no credit data for the contracts. |
| Short stock sources | `List[ShortStockSource]`; Python object exposes `ts` | `Vec<ShortStockSource>` JSON with server date/time fields | CLI output may be JSON or formatted | Empty array can be normal if no source exists. Do not use Python `ts` in HTTP typed clients. |
| Scanner | `List[ScannerItem]`; Python object exposes `ts` | `Vec<ScannerItem>` JSON with `datetime` | `shioaji data scanner --format json` follows scanner JSON; default output may be formatted | Ranking response; `count` limits size. Do not use Python `ts` in HTTP typed clients. |
| Regulatory punish | `PunishResp`; Python may expose `date` / `datetime` values | `PunishResp` JSON | CLI output, if available, may be formatted | Use for disposition stocks; do not assume Python date objects in HTTP JSON. |
| Regulatory notice | `NoticeResp`; Python may expose `date` / `datetime` values | `NoticeResp` JSON | CLI output, if available, may be formatted | Use for attention stocks; do not assume Python date objects in HTTP JSON. |

## Snapshots 即時快照

Get current snapshot for multiple contracts (max 500 per request).
取得多個合約的當前快照（每次最多 500 個）。

### Python

```python
import shioaji as sj

api = sj.Shioaji()
api.login(
    api_key="YOUR_KEY",
    secret_key="YOUR_SECRET",
    contracts_timeout=10000,  # Wait before using api.Contracts immediately
)

contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
]

snapshots = api.snapshots(contracts)

for snap in snapshots:
    print(f"{snap.code}: {snap.close} ({snap.change_price})")
```

### HTTP: Get Snapshots

```bash
# POST /api/v1/data/snapshots
curl -X POST http://localhost:8080/api/v1/data/snapshots \
  -H "Content-Type: application/json" \
  -d '{
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2330"},
      {"security_type": "STK", "exchange": "TSE", "code": "2317"}
    ]
  }'
```

### Python Snapshot Attributes Python 快照屬性

Python `api.snapshots()` exposes `ts` as a timestamp field. HTTP `POST /api/v1/data/snapshots` returns `datetime` as an ISO-like datetime string instead; JavaScript, Go, Rust, and other HTTP clients should decode `datetime`, not `ts`.
Python `api.snapshots()` 會暴露 `ts` 時間戳欄位；HTTP `POST /api/v1/data/snapshots` 則回傳 `datetime` 字串。JavaScript、Go、Rust 等 HTTP client 不要期待 `ts` 欄位。

```python
snap.ts              # int: Timestamp 時間戳
snap.code            # str: Stock code 股票代碼
snap.exchange        # str: Exchange 交易所
snap.open            # float: Open price 開盤價
snap.high            # float: High price 最高價
snap.low             # float: Low price 最低價
snap.close           # float: Close price 收盤價
snap.tick_type       # TickType: Buy/Sell 內外盤
snap.change_price    # float: Price change 漲跌價
snap.change_rate     # float: Change rate % 漲跌幅
snap.change_type     # ChangeType: Up/Down/Unchanged/LimitUp/LimitDown
snap.average_price   # float: Average price 均價
snap.volume          # int: Last volume 最後成交量
snap.total_volume    # int: Total volume 總成交量
snap.amount          # int: Last amount 最後成交金額
snap.total_amount    # int: Total amount 總成交金額
snap.yesterday_volume # float: Yesterday volume 昨日成交量
snap.buy_price       # float: Bid price 買價
snap.buy_volume      # float: Bid volume 買量
snap.sell_price      # float: Ask price 賣價
snap.sell_volume     # int: Ask volume 賣量
snap.volume_ratio    # float: Volume ratio 量比
```

### HTTP Snapshot Response HTTP 快照回應

HTTP clients receive JSON from the server schema. The time field is `datetime`.
HTTP client 收到的是 server JSON schema，時間欄位是 `datetime`。

```json
[
  {
    "datetime": "2026-05-27T14:30:00",
    "code": "2330",
    "exchange": "TSE",
    "open": 2310,
    "high": 2330,
    "low": 2290,
    "close": 2300,
    "volume": 154,
    "total_volume": 31818
  }
]
```

---

## Historical Ticks 歷史 Tick 資料

Query historical tick data by date, time range, or last count.
依日期、時間區間或筆數查詢歷史逐筆資料。

The examples below assume `api.Contracts` is ready. If the script logs in and immediately queries data, use `contracts_timeout` during login or check contract loading first.
以下範例假設 `api.Contracts` 已載入完成。若程式登入後立刻查資料，請在 login 使用 `contracts_timeout`，或先確認商品檔已完成載入。

### By Date 依日期

```python
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2023-01-16",
)
```

### By Time Range 依時間區間

```python
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2023-01-16",
    query_type=sj.TicksQueryType.RangeTime,
    time_start="09:00:00",
    time_end="09:20:01",
)
```

### Last Count 最後 N 筆

```python
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2023-01-16",
    query_type=sj.TicksQueryType.LastCount,
    last_cnt=100,
)
```

### HTTP: Get Ticks

```bash
# POST /api/v1/data/ticks
curl -X POST http://localhost:8080/api/v1/data/ticks \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "STK", "exchange": "TSE", "code": "2330"},
    "date": "2023-01-16",
    "query_type": "AllDay"
  }'

# With time range 附時間區間
curl -X POST http://localhost:8080/api/v1/data/ticks \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "STK", "exchange": "TSE", "code": "2330"},
    "date": "2023-01-16",
    "query_type": "RangeTime",
    "time_start": "09:00:00",
    "time_end": "09:20:01"
  }'

# Last N ticks 最後 N 筆
curl -X POST http://localhost:8080/api/v1/data/ticks \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "STK", "exchange": "TSE", "code": "2330"},
    "date": "2023-01-16",
    "query_type": "LastCount",
    "last_cnt": 100
  }'
```

### Ticks Attributes Tick 屬性

These are Python `api.ticks()` wrapper attributes. HTTP `POST /api/v1/data/ticks` returns the server JSON schema with `datetime` as the time column; HTTP clients should not expect Python's `ts` key.
以下是 Python `api.ticks()` wrapper 屬性。HTTP `POST /api/v1/data/ticks` 回傳 server JSON schema，時間欄位是 `datetime`；HTTP client 不要期待 Python 的 `ts` key。

```python
ticks.ts          # List[int]: Timestamps 時間戳
ticks.close       # List[float]: Close prices 成交價
ticks.volume      # List[int]: Volumes 成交量
ticks.bid_price   # List[float]: Bid prices 買價
ticks.bid_volume  # List[int]: Bid volumes 買量
ticks.ask_price   # List[float]: Ask prices 賣價
ticks.ask_volume  # List[int]: Ask volumes 賣量
ticks.tick_type   # List[int]: 1=外盤, 2=內盤, 0=無法判定
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

df = pl.DataFrame({**ticks}).with_columns(
    pl.col("ts").cast(pl.Datetime("ns"))
)
```

---

## Historical KBars 歷史 K 棒

Query historical 1-minute K-bar data.
查詢歷史 1 分鐘 K 棒資料。

### Python

```python
kbars = api.kbars(
    contract=api.Contracts.Stocks["2330"],
    start="2023-01-15",
    end="2023-01-16",
)
```

### HTTP: Get KBars

```bash
# POST /api/v1/data/kbars
curl -X POST http://localhost:8080/api/v1/data/kbars \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "STK", "exchange": "TSE", "code": "2330"},
    "start": "2023-01-15",
    "end": "2023-01-16"
  }'
```

### KBars Attributes K 棒屬性

These are Python `api.kbars()` wrapper attributes. HTTP `POST /api/v1/data/kbars` returns the server JSON schema with `datetime` as the time column; HTTP clients should not expect Python's `ts` key.
以下是 Python `api.kbars()` wrapper 屬性。HTTP `POST /api/v1/data/kbars` 回傳 server JSON schema，時間欄位是 `datetime`；HTTP client 不要期待 Python 的 `ts` key。

```python
kbars.ts      # List[int]: Timestamps 時間戳
kbars.Open    # List[float]: Open prices 開盤價
kbars.High    # List[float]: High prices 最高價
kbars.Low     # List[float]: Low prices 最低價
kbars.Close   # List[float]: Close prices 收盤價
kbars.Volume  # List[int]: Volumes 成交量
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

df = pl.DataFrame({**kbars}).with_columns(
    pl.col("ts").cast(pl.Datetime("ns"))
)
```

---

## Daily Quotes 每日行情

Get daily market quotes for all stocks.
取得所有股票的每日行情資料。

### Python

```python
import datetime

daily = api.daily_quotes(date=datetime.date(2023, 1, 16))
# `date=` accepts datetime.date or datetime.datetime (date portion).
# Strings are NOT accepted at the Python boundary; convert with
# datetime.date.fromisoformat("2023-01-16") if you have a string.
```

### HTTP: Get Daily Quotes

```bash
# POST /api/v1/data/daily_quotes
curl -X POST http://localhost:8080/api/v1/data/daily_quotes \
  -H "Content-Type: application/json" \
  -d '{"date": "2023-01-16", "exclude": false}'
```

---

## Continuous Futures 連續期貨

For historical data of expired futures, use continuous contracts `R1` (near-month) and `R2` (next-to-near-month).
查詢已過期期貨的歷史資料，使用連續合約 `R1`（近月）和 `R2`（次近月）。

```python
# Continuous near-month futures 連續近月期貨
ticks = api.ticks(
    contract=api.Contracts.Futures.TXF.TXFR1,
    date="2023-01-16",
)

kbars = api.kbars(
    contract=api.Contracts.Futures.TXF.TXFR1,
    start="2023-01-15",
    end="2023-01-16",
)
```

### Historical Data Periods 歷史資料可查詢區間

| Type 類型 | Start Date 起始日 |
|-----------|-------------------|
| Index 指數 | 2020-03-02 |
| Stock 股票 | 2020-03-02 |
| Futures 期貨 | 2020-03-22 |

---

## Credit Enquiries 資券餘額查詢

Query margin and short unit information for stocks.
查詢股票的融資融券餘額資訊。

### Python

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2890"],
]

credit_enquires = api.credit_enquires(contracts)
```

### HTTP: Get Credit Enquiries

```bash
# POST /api/v1/data/credit_enquire
curl -X POST http://localhost:8080/api/v1/data/credit_enquire \
  -H "Content-Type: application/json" \
  -d '{
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2330"},
      {"security_type": "STK", "exchange": "TSE", "code": "2890"}
    ]
  }'
```

### CreditEnquire Attributes 資券餘額屬性

```python
enquire.update_time   # str: Update time 更新時間
enquire.system        # str: System code 系統代碼
enquire.stock_id      # str: Stock code 股票代碼
enquire.margin_unit   # int: Margin units 融資餘額
enquire.short_unit    # int: Short units 融券餘額
```

---

## Short Stock Sources 券源查詢

Query available short stock sources.
查詢可借券數量。

### Python

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
]

short_sources = api.short_stock_sources(contracts)
```

### HTTP: Get Short Stock Sources

```bash
# POST /api/v1/data/short_stock_sources
curl -X POST http://localhost:8080/api/v1/data/short_stock_sources \
  -H "Content-Type: application/json" \
  -d '{
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2330"},
      {"security_type": "STK", "exchange": "TSE", "code": "2317"}
    ]
  }'
```

### ShortStockSource Attributes 券源屬性

These are Python `api.short_stock_sources()` wrapper attributes. HTTP `POST /api/v1/data/short_stock_sources` returns the server JSON schema with `datetime`; HTTP clients should not expect Python's `ts` key.
以下是 Python `api.short_stock_sources()` wrapper 屬性。HTTP `POST /api/v1/data/short_stock_sources` 回傳 server JSON schema，時間欄位是 `datetime`；HTTP client 不要期待 Python 的 `ts` key。

```python
source.code               # str: Stock code 股票代碼
source.short_stock_source # int: Available shares 可借券數量
source.ts                 # int: Timestamp 時間戳
```

---

## Scanners 掃描器排行

Get market rankings by various criteria.
依各種條件取得市場排行。

### Scanner Types 掃描器類型

```python
sj.ScannerType.ChangePercentRank  # 漲跌幅排行
sj.ScannerType.ChangePriceRank    # 漲跌價排行
sj.ScannerType.DayRangeRank       # 振幅排行
sj.ScannerType.VolumeRank         # 成交量排行
sj.ScannerType.AmountRank         # 成交金額排行
```

### Python

```python
# Top 10 gainers 漲幅前 10 名
scanners = api.scanners(
    scanner_type=sj.ScannerType.ChangePercentRank,
    ascending=False,
    count=10,
)

# Top 10 losers 跌幅前 10 名
scanners = api.scanners(
    scanner_type=sj.ScannerType.ChangePercentRank,
    ascending=True,
    count=10,
)
```

### HTTP: Get Scanners

```bash
# POST /api/v1/data/scanner
curl -X POST http://localhost:8080/api/v1/data/scanner \
  -H "Content-Type: application/json" \
  -d '{
    "scanner_type": "ChangePercentRank",
    "date": "2023-01-16",
    "ascending": false,
    "count": 10
  }'
```

### Scanner Attributes 掃描器屬性

These are Python `api.scanners()` wrapper attributes. HTTP `POST /api/v1/data/scanner` returns the server JSON schema with `datetime`; HTTP clients should not expect Python's `ts` key.
以下是 Python `api.scanners()` wrapper 屬性。HTTP `POST /api/v1/data/scanner` 回傳 server JSON schema，時間欄位是 `datetime`；HTTP client 不要期待 Python 的 `ts` key。

```python
scan.date            # str: Trade date 交易日
scan.code            # str: Stock code 股票代碼
scan.name            # str: Stock name 股票名稱
scan.ts              # int: Timestamp 時間戳
scan.open            # float: Open price 開盤價
scan.high            # float: High price 最高價
scan.low             # float: Low price 最低價
scan.close           # float: Close price 收盤價
scan.price_range     # float: Day range 振幅
scan.change_price    # float: Price change 漲跌價
scan.change_type     # int: Change type 漲跌類型
scan.average_price   # float: Average price 均價
scan.volume          # int: Last volume 最後成交量
scan.total_volume    # int: Total volume 總成交量
scan.amount          # int: Last amount 最後成交金額
scan.total_amount    # int: Total amount 總成交金額
scan.yesterday_volume # int: Yesterday volume 昨日成交量
scan.volume_ratio    # float: Volume ratio 量比
scan.buy_price       # float: Bid price 買價
scan.buy_volume      # int: Bid volume 買量
scan.sell_price      # float: Ask price 賣價
scan.sell_volume     # int: Ask volume 賣量
scan.bid_orders      # int: Bid side orders 內盤成交單數
scan.bid_volumes     # int: Bid side volume 內盤成交量
scan.ask_orders      # int: Ask side orders 外盤成交單數
scan.ask_volumes     # int: Ask side volume 外盤成交量
scan.tick_type       # int: 1=外盤, 2=內盤, 0=無法判定
```

---

## Disposition Stocks 處置股

Query stocks under trading restrictions.
查詢受交易限制的處置股清單。

### Python

```python
punish = api.punish()
```

### HTTP: Get Disposition Stocks

```bash
# GET /api/v1/data/regulatory_punish
curl http://localhost:8080/api/v1/data/regulatory_punish
```

### Punish Attributes 處置股屬性

```python
punish.code            # List[str]: Stock codes 股票代碼
punish.start_date      # List[date]: Disposition start date 處置開始日
punish.end_date        # List[date]: Disposition end date 處置結束日
punish.updated_at      # List[datetime]: Updated time 更新時間
punish.interval        # List[str]: Matching interval 撮合間隔
punish.unit_limit      # List[float]: Single order limit % 單筆限額
punish.total_limit     # List[float]: Daily order limit % 每日限額
punish.description     # List[str]: Description 說明
punish.announced_date  # List[date]: Announced date 公告日
```

---

## Attention Stocks 注意股

Query stocks under attention.
查詢受注意的股票清單。

### Python

```python
notice = api.notice()
```

### HTTP: Get Attention Stocks

```bash
# GET /api/v1/data/regulatory_notice
curl http://localhost:8080/api/v1/data/regulatory_notice
```

### Notice Attributes 注意股屬性

```python
notice.code            # List[str]: Stock codes 股票代碼
notice.updated_at      # List[datetime]: Updated time 更新時間
notice.close           # List[float]: Close price 收盤價
notice.reason          # List[str]: Attention reason 注意原因
notice.announced_date  # List[date]: Announced date 公告日
```

---

## Convert to Polars 轉換為 Polars

All list-based response objects can be converted to Polars DataFrames:
所有列表型回應物件都可轉換為 Polars DataFrame：

```python
import polars as pl

# Snapshots 快照
df = pl.DataFrame([s.dict() for s in snapshots])

# Credit enquiries 資券餘額
df = pl.DataFrame([c.dict() for c in credit_enquires])

# Scanners 掃描器
df = pl.DataFrame([s.dict() for s in scanners])

# Regulatory 監管
df = pl.DataFrame(punish.dict())
df = pl.DataFrame(notice.dict())
```

For full HTTP endpoint inventory, see [HTTP_API.md](HTTP_API.md).
完整的 HTTP 端點清單請參見 [HTTP_API.md](HTTP_API.md)。
