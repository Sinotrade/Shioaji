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
| Daily quotes | `DailyQuotes`; Python date values are `datetime.date` | `DailyQuotes` JSON | `shioaji data daily-quotes --format json` follows HTTP JSON; non-JSON formats transpose to rows | Python `date=` accepts `datetime.date` / `datetime.datetime`, not strings. Empty fields usually mean no data for the date/exclude combination. |
| Credit enquiry | `List[CreditEnquire]` | `Vec<CreditEnquire>` JSON | `shioaji data credit-enquire --format json` follows HTTP JSON; default output may be formatted | Empty array can mean no credit data for the contracts. |
| Short stock sources | `List[ShortStockSource]`; Python object exposes `ts` | `Vec<ShortStockSource>` JSON with server date/time fields | `shioaji data short-stock-sources --format json` follows HTTP JSON; default output may be formatted | Empty array can be normal if no source exists. Do not use Python `ts` in HTTP typed clients. |
| Scanner | `List[ScannerItem]`; Python object exposes `ts` | `Vec<ScannerItem>` JSON with `datetime` | `shioaji data scanner --format json` follows scanner JSON; default output may be formatted | Ranking response; `count` limits size. Do not use Python `ts` in HTTP typed clients. |
| Regulatory punish | `PunishResp`; Python may expose `date` / `datetime` values | `PunishResp` JSON | `shioaji data regulatory --type punish --format json` follows HTTP JSON; non-JSON formats transpose to rows | Use for disposition stocks; do not assume Python date objects in HTTP JSON. |
| Regulatory notice | `NoticeResp`; Python may expose `date` / `datetime` values | `NoticeResp` JSON | `shioaji data regulatory --type notice --format json` follows HTTP JSON; non-JSON formats transpose to rows | Use for attention stocks; do not assume Python date objects in HTTP JSON. |

## Market Data Time Handling 行情資料時間處理

For market-data fields in this file, do not treat Shioaji Python `ts` values as
UTC and do not add 8 hours. Historical `api.ticks().ts` and `api.kbars().ts`
are nanosecond timestamps encoded so `pd.to_datetime(...)` / Polars
`cast(pl.Datetime("ns"))` already yields Taiwan market wall-clock time. Adding
`+8h` shifts the data to the wrong session; for example, a stock `09:01` K-bar
becomes `17:01`.

本文件的行情資料欄位不要把 Python `ts` 當 UTC，也不要自行 `+8` 小時。
歷史 `api.ticks().ts` 與 `api.kbars().ts` 是 nanosecond timestamp，直接
`pd.to_datetime(...)` 或 Polars `cast(pl.Datetime("ns"))` 解出來就是台灣
市場牆鐘時間；自行 `+8h` 會把資料移到錯誤時段，例如股票 `09:01` K 棒會
變成 `17:01`。

```python
import pandas as pd

# Correct: direct market-data timestamp decode.
ticks_dt = pd.to_datetime(ticks.ts)
kbars_dt = pd.to_datetime(kbars.ts)

# Wrong: do not add 8 hours to Shioaji market-data ts.
wrong = pd.to_datetime(kbars.ts) + pd.Timedelta(hours=8)
```

If downstream code requires timezone-aware datetimes, attach Asia/Taipei without
shifting the clock time. Do not parse as UTC and convert to Asia/Taipei.

若下游需要 timezone-aware datetime，請在不移動牆鐘時間的前提下標上
Asia/Taipei；不要先當 UTC parse 再 convert 到 Asia/Taipei。

```python
import pandas as pd
import polars as pl

ticks_dt_tz = pd.to_datetime(ticks.ts).tz_localize("Asia/Taipei")

ticks_pl = pl.DataFrame({**ticks}).with_columns(
    pl.col("ts")
    .cast(pl.Datetime("ns"))
    .dt.replace_time_zone("Asia/Taipei")
)
```

Streaming market-data callback objects follow the same market-time rule:
`tick.datetime` / `bidask.datetime` are already Taiwan market datetimes; do not
add 8 hours. This note is scoped to market data only. Do not infer order,
trade, deal, or account timestamp behavior from it.

即時行情 callback 物件也遵守同一個市場時間規則：`tick.datetime` /
`bidask.datetime` 已經是台灣市場時間，不要再 `+8` 小時。此段只適用於
行情資料；不要把它外推到委託、交易、成交或帳務 timestamp。

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

### KBar Date Range Limit and Usage Pattern K 棒日期區間限制與使用方式

`api.kbars()` accepts historical backfill, but one request must not exceed 30
calendar days. If the range is too long, the server returns `400: Kbars date
range must not exceed 30 days`. This is a per-request window limit, not "only
the latest 30 days are available". Use chunks of 29 days or less to avoid
inclusive-boundary confusion.

`api.kbars()` 可用於歷史回補，但單次 request 不可超過 30 個 calendar
days。區間太長時 server 會回 `400: Kbars date range must not exceed 30
days`。這是單次 request 的窗口限制，不是「只能回溯最近 30 天」。建議每段
切成 29 天以內，避免 inclusive boundary 誤差。

For intraday systems, do not keep querying long ranges during market hours. Use
30-day chunks only for backfill. During the session, query only today's changing
data and merge it into a local data manager backed by a columnar, partitioned
format such as Parquet. For long-term daily history, use TWSE daily data instead
of repeatedly pulling minute K-bars.

盤中系統不要反覆查長天期 K 棒。30 天分段是方便回補資料，不是盤中使用方式。
盤中只查當天會變動的資料，合併進本地 data manager；底層建議用 Parquet
這類 columnar、可 partition、可跨語言讀取的格式。長期日線資料請用 TWSE
日線，不要反覆拉長天期分鐘 K。

```python
import datetime as dt
from pathlib import Path

import polars as pl


def date_chunks(start: str, end: str, days: int = 29):
    cur = dt.date.fromisoformat(start)
    last = dt.date.fromisoformat(end)
    step = dt.timedelta(days=days - 1)
    while cur <= last:
        chunk_end = min(cur + step, last)
        yield cur.isoformat(), chunk_end.isoformat()
        cur = chunk_end + dt.timedelta(days=1)


class KBarDataManager:
    def __init__(self, root: str):
        self.root = Path(root)

    def _file(self, code: str, date: dt.date) -> Path:
        return self.root / f"code={code}" / f"date={date.isoformat()}" / "kbars.parquet"

    def write(self, code: str, frame: pl.DataFrame) -> None:
        frame = frame.sort("ts").unique(subset=["ts"], keep="last", maintain_order=True)
        for key, day_frame in frame.group_by("date"):
            trade_date = key[0] if isinstance(key, tuple) else key
            file = self._file(code, trade_date)
            file.parent.mkdir(parents=True, exist_ok=True)
            if file.exists():
                existing = pl.read_parquet(file)
                day_frame = (
                    pl.concat([existing, day_frame])
                    .sort("ts")
                    .unique(subset=["ts"], keep="last", maintain_order=True)
                )
            day_frame.write_parquet(file)

    def scan(self, code: str) -> pl.LazyFrame:
        return pl.scan_parquet(str(self.root / f"code={code}" / "date=*" / "kbars.parquet"))


def kbars_frame(kbars) -> pl.DataFrame:
    return (
        pl.DataFrame({**kbars})
        .with_columns(pl.col("ts").cast(pl.Datetime("ns")).alias("datetime"))
        .with_columns(pl.col("datetime").dt.date().alias("date"))
    )


def backfill_kbars(api, contract, start: str, end: str, manager: KBarDataManager):
    """Backfill immutable history in <=29-day request windows."""

    for chunk_start, chunk_end in date_chunks(start, end):
        kbars = api.kbars(contract, start=chunk_start, end=chunk_end)
        manager.write(contract.code, kbars_frame(kbars))


def refresh_today_kbars(api, contract, manager: KBarDataManager):
    """Intraday refresh only touches today's mutable partition."""
    today = dt.date.today().isoformat()
    kbars = api.kbars(contract, start=today, end=today)
    manager.write(contract.code, kbars_frame(kbars))


manager = KBarDataManager("./market-data/kbars")
contract = api.Contracts.Stocks["2330"]

# Backfill historical partitions in chunks.
backfill_kbars(api, contract, "2024-01-01", "2024-12-31", manager)

# Intraday refresh: only query today's changing partition, then upsert locally.
refresh_today_kbars(api, contract, manager)
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

### Resample Ticks to API-Compatible 1-Minute KBars 用 Tick 自聚成 API 對齊的一分鐘 K 棒

`api.kbars()` 1-minute bars are right-labelled: for normal intraday minutes,
the bar timestamp is the minute end and the content is `[ts - 1 minute, ts)`.
When rebuilding bars from `api.ticks()`, start from the bar semantics. A
right-labelled 1-minute bar groups ticks into `[ts - 1 minute, ts)`, so compute
that right-labelled bucket directly with `dt.truncate("1m") + 1 minute`, then
use normal `group_by`.
`group_by_dynamic(..., closed="left", label="right")` is also valid after the
same close-boundary adjustment, but it is not required for this case.

Before grouping, shrink exact session-close boundary ticks by 1 microsecond.
This keeps Shioaji's close-auction tick in the close-labelled K-bar while still
using the normal truncate-and-group rule. Verified examples:

- Stock day session: exact `13:30:00` ticks belong to the `13:30` K-bar.
- Futures day session: exact `13:45:00` ticks belong to the `13:45` K-bar.

`api.kbars()` 一分鐘 K 棒是右標：一般分鐘內容是 `[ts - 1 分鐘, ts)`。
自聚 tick 要先從 K 棒語意理解：右標一分鐘 K 棒把 tick 分到
`[ts - 1 分鐘, ts)`，所以直接用 `dt.truncate("1m") + 1 分鐘` 算出
右標 bucket，再做一般 `group_by`。若使用 dynamic window，也是在同樣的
close-boundary 調整後使用 `group_by_dynamic(..., closed="left",
label="right")` 表達同一個分組語意。session close 邊界 tick 先內縮
1 微秒後再分 bucket。
實測 2330 股票日盤與 TXFR1 期貨日盤：股票 `13:30:00` 收盤集合競價 tick
歸在 `13:30` K 棒；期貨日盤 `13:45:00` 邊界 tick 歸在 `13:45` K 棒。

```python
import datetime as dt
import polars as pl

date = "2025-01-06"
contract = api.Contracts.Stocks["2330"]

# For futures day session, use a futures contract and switch these settings:
# contract = api.Contracts.Futures.TXF.TXFR1
# session_start = dt.datetime.fromisoformat(f"{date} 08:45:00")
# session_close = dt.datetime.fromisoformat(f"{date} 13:45:00")
# amount_multiplier = 1
session_start = dt.datetime.fromisoformat(f"{date} 09:00:00")
session_close = dt.datetime.fromisoformat(f"{date} 13:30:00")
amount_multiplier = 1000

ticks = api.ticks(contract, date=date)

ticks_df = (
    pl.DataFrame(
        {
            "ts": ticks.ts,
            "price": ticks.close,
            "volume": ticks.volume,
        }
    )
    .with_columns(pl.col("ts").cast(pl.Datetime("ns")))
    .sort("ts")
)

bars = (
    ticks_df
    .filter((pl.col("ts") >= session_start) & (pl.col("ts") <= session_close))
    .with_columns(
        pl.when(pl.col("ts") == session_close)
        .then(pl.col("ts") - pl.duration(microseconds=1))
        .otherwise(pl.col("ts"))
        .cast(pl.Datetime("ns"))
        .alias("ts_for_bucket")
    )
    .with_columns(
        (pl.col("ts_for_bucket").dt.truncate("1m") + pl.duration(minutes=1))
        .alias("ts")
    )
    .group_by("ts", maintain_order=True)
    .agg(
        pl.col("price").first().alias("Open"),
        pl.col("price").max().alias("High"),
        pl.col("price").min().alias("Low"),
        pl.col("price").last().alias("Close"),
        pl.col("volume").sum().alias("Volume"),
        (pl.col("price") * pl.col("volume") * amount_multiplier)
        .sum()
        .alias("Amount"),
    )
    .sort("ts")
)
```

The Polars dynamic-window form follows the same basic concept: keep the same
`ts_for_bucket` adjustment, then let `group_by_dynamic` express the
left-closed, right-labelled window. The result timestamp column is the window
label, so rename it back to `ts` for Shioaji-style output.

```python
bars_dynamic = (
    ticks_df
    .filter((pl.col("ts") >= session_start) & (pl.col("ts") <= session_close))
    .with_columns(
        pl.when(pl.col("ts") == session_close)
        .then(pl.col("ts") - pl.duration(microseconds=1))
        .otherwise(pl.col("ts"))
        .cast(pl.Datetime("ns"))
        .alias("ts_for_bucket")
    )
    .group_by_dynamic(
        "ts_for_bucket",
        every="1m",
        period="1m",
        closed="left",
        label="right",
    )
    .agg(
        pl.col("price").first().alias("Open"),
        pl.col("price").max().alias("High"),
        pl.col("price").min().alias("Low"),
        pl.col("price").last().alias("Close"),
        pl.col("volume").sum().alias("Volume"),
        (pl.col("price") * pl.col("volume") * amount_multiplier)
        .sum()
        .alias("Amount"),
    )
    .rename({"ts_for_bucket": "ts"})
    .sort("ts")
)
```

Use `amount_multiplier = 1000` for stock ticks because stock tick volume is in
lots. Use `amount_multiplier = 1` for futures ticks. For futures, choose the
session window explicitly; the day session starts at `08:45:00`, first
right-labelled bar is `08:46:00`, and the day close bar is labelled `13:45`.

Pandas follows the same rule: shrink the close-boundary tick first, then build
the right-labelled bucket with `floor("min") + 1 minute` and use normal
`groupby`.

```python
import pandas as pd

date = "2025-01-06"
session_start = pd.Timestamp(f"{date} 09:00:00")
session_close = pd.Timestamp(f"{date} 13:30:00")
amount_multiplier = 1000

ticks_pd = pd.DataFrame(
    {
        "ts": pd.to_datetime(ticks.ts),
        "price": ticks.close,
        "volume": ticks.volume,
    }
)
ticks_pd = ticks_pd[
    (ticks_pd["ts"] >= session_start) & (ticks_pd["ts"] <= session_close)
].copy()
ticks_pd.loc[ticks_pd["ts"] == session_close, "ts"] -= pd.Timedelta(
    microseconds=1
)
ticks_pd["bar_ts"] = ticks_pd["ts"].dt.floor("min") + pd.Timedelta(minutes=1)
ticks_pd["amount"] = ticks_pd["price"] * ticks_pd["volume"] * amount_multiplier

bars_pd = (
    ticks_pd.groupby("bar_ts", sort=True)
    .agg(
        Open=("price", "first"),
        High=("price", "max"),
        Low=("price", "min"),
        Close=("price", "last"),
        Volume=("volume", "sum"),
        Amount=("amount", "sum"),
    )
)
```

For left-labelled display, add a separate display column instead of changing the
canonical Shioaji timestamp. For normal bars, `bar_start = ts - 1 minute`.
Treat the close-auction bar specially in UI/signals if needed, because it
represents the close boundary auction tick, not a normal
`[close - 1 minute, close)` interval.

```python
bars_for_display = bars.with_columns(
    (pl.col("ts") - pl.duration(minutes=1)).alias("bar_start")
)
```

Do not look ahead. A right-labelled `09:01` bar is complete only after
`09:01:00`; the close bar is complete only after the close-auction tick is
available. Some `api.kbars()` responses may include zero-volume carry-forward
bars that cannot be produced by a pure tick aggregation unless you build the
session calendar and fill no-trade minutes explicitly.

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

### CLI: Get Daily Quotes

```bash
shioaji data daily-quotes                          # today 今日
shioaji data daily-quotes --date 2023-01-16
shioaji data daily-quotes --date 2023-01-16                       # warrants excluded by default 預設排除權證
shioaji data daily-quotes --date 2023-01-16 --exclude-warrant=false   # include warrants 含權證
shioaji data daily-quotes -f json                  # column-oriented HTTP JSON 欄位導向 JSON
```

Default `toon`/`human` output transposes to per-stock rows; `-f json` follows the HTTP column-oriented `DailyQuotes` schema.
預設 `toon`/`human` 輸出會轉置為逐檔列；`-f json` 沿用 HTTP 欄位導向的 `DailyQuotes` 格式。

---

## Continuous Futures 連續期貨

For historical data of expired futures, use continuous contracts `R1` (near-month) and `R2` (next-to-near-month).
查詢已過期期貨的歷史資料，使用連續合約 `R1`（近月）和 `R2`（次近月）。

For futures ticks, `api.ticks(contract, date=D)` uses the futures trading-day
assignment: the night session is attached to the next trading day. In practical
terms, `date=D` covers the session from the previous trading day's `15:00`
night-session open through `D 13:45` day-session close. Do not query the
previous calendar date expecting to get that night session; use the trading day
it belongs to.

期貨 ticks 的 `api.ticks(contract, date=D)` 使用期貨交易日歸屬：夜盤掛在
下一個交易日。實務上，`date=D` 涵蓋前一交易日 `15:00` 夜盤開盤到
`D 13:45` 日盤收盤。不要用前一個 calendar date 查那段夜盤；請用夜盤歸屬
的交易日。

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

### CLI: Get Credit Enquiries

```bash
shioaji data credit-enquire --codes 2330,2890
shioaji data credit-enquire --codes 2330,2890 -f json
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

### CLI: Get Short Stock Sources

```bash
shioaji data short-stock-sources --codes 2330,2317
shioaji data short-stock-sources --codes 2330,2317 -f json
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

### CLI: Get Disposition Stocks

```bash
shioaji data regulatory                  # --type punish is the default 預設即為處置股
shioaji data regulatory --type punish
shioaji data regulatory --type punish -f json
```

Default `toon`/`human` output transposes to per-stock rows; `-f json` follows the HTTP column-oriented `PunishResp` schema.
預設 `toon`/`human` 輸出會轉置為逐檔列；`-f json` 沿用 HTTP 欄位導向的 `PunishResp` 格式。

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

### CLI: Get Attention Stocks

```bash
shioaji data regulatory --type notice
shioaji data regulatory --type notice -f json
```

Default `toon`/`human` output transposes to per-stock rows; `-f json` follows the HTTP column-oriented `NoticeResp` schema.
預設 `toon`/`human` 輸出會轉置為逐檔列；`-f json` 沿用 HTTP 欄位導向的 `NoticeResp` 格式。

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
