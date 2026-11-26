# Market Data 市場資料

This document covers historical data, snapshots, daily quotes, credit enquiries, short stock sources, scanners, and disposition/attention stocks in Shioaji.
本文件說明 Shioaji 中的歷史資料查詢、快照、每日行情、資券餘額查詢、券源查詢、掃描器排行及處置/注意股。

US stocks (`region="US"`, 1.8.0) use the same `api.snapshots()`, `api.ticks()` and `api.kbars()`; their return types, UTC timestamps and limits are in [US Market Data](#us-market-data-美股歷史行情與快照). Everything else in this file is Taiwan only.
美股（1.8.0）沿用同一組 `api.snapshots()`／`api.ticks()`／`api.kbars()`，回傳型別、UTC 時間與限制見 [US Market Data](#us-market-data-美股歷史行情與快照)；本文件其餘功能僅限台股。

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

> **US contracts are the exception.** US `UsSnapshot.ts`, `UsTicks.ts` and US
> `api.kbars().ts` are true UTC epoch nanoseconds; decode them as UTC
> (`pd.to_datetime(ts, utc=True)`) and convert to `America/New_York` if needed.
> See [US Market Data](#us-market-data-美股歷史行情與快照). The rules below
> are for Taiwan contracts.
> **美股例外**：美股的 `ts` 是真正的 UTC epoch ns，要當 UTC 解；下面規則只適用台股。

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

Get current snapshot for multiple contracts (max 2500 per request, Taiwan and US contracts combined). US contracts return `UsSnapshot`; see [US Snapshots](#us-snapshots-美股快照).
取得多個合約的當前快照（每次最多 2500 個，台美合計）。美股合約回 `UsSnapshot`，見 [US Snapshots](#us-snapshots-美股快照)。

### Python

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

contracts = [
    api.contracts.get("2330"),
    api.contracts.get("2317"),
]
if any(contract is None for contract in contracts):
    raise LookupError("snapshot contract not found")

snapshots = api.snapshots(contracts)

for snap in snapshots:
    print(f"{snap.code}: {snap.close} ({snap.change_price})")
```

Combo snapshots use the same structured `ComboContract` built from two normal
Contract V2 legs:

```python
first = api.contracts.get("TXFL6")
second = api.contracts.get("TXFC7")
if first is None or second is None:
    raise LookupError("combo leg not found")
combo = api.contracts.combo(legs=[first, second])
combo_snapshot = api.snapshots([combo])
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

HTTP combo snapshot requests put the structured combo directly in the
`contracts` list. The native slash key is never a public input:

```json
{
  "contracts": [{
    "legs": [
      {"security_type":"FUT", "exchange":"TAIFEX", "code":"TXFL6"},
      {"security_type":"FUT", "exchange":"TAIFEX", "code":"TXFC7"}
    ]
  }]
}
```

CLI form: `shioaji data snapshots --codes 'TXFL6+TXFC7'`.

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

The examples below use Contract V2. Resolve each Base through `api.contracts`; the required dataset is loaded lazily on first access.
以下範例使用 Contract V2。請透過 `api.contracts` 解析 Base contract；第一次存取時會按需載入所需資料。

### By Date 依日期

```python
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")
ticks = api.ticks(
    contract=contract,
    date="2023-01-16",
)
```

The `contract` argument may also be a structured futures combo built with
`api.contracts.combo()` (option combos have no market data):

```python
ticks = api.ticks(contract=combo, date="2026-07-17")
```

### By Time Range 依時間區間

```python
ticks = api.ticks(
    contract=contract,
    date="2023-01-16",
    query_type=sj.TicksQueryType.RangeTime,
    time_start="09:00:00",
    time_end="09:20:01",
)
```

### Last Count 最後 N 筆

```python
ticks = api.ticks(
    contract=contract,
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

HTTP combo ticks replace the regular `contract` object with structured legs:

```json
{
  "contract": {
    "legs": [
      {"security_type":"FUT", "exchange":"TAIFEX", "code":"TXFL6"},
      {"security_type":"FUT", "exchange":"TAIFEX", "code":"TXFC7"}
    ]
  },
  "date": "2026-07-17",
  "query_type": "AllDay"
}
```

CLI form: `shioaji data ticks --code TXFL6 --combo-with TXFC7 --date 2026-07-17 --all`.

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

> Realtime KBar push (`QuoteType.KBar` subscription, SSE `stream/data/kbar`) is different — see [STREAMING.md](STREAMING.md).
> 即時 K 棒推送是另一回事（`QuoteType.KBar` 訂閱），見 [STREAMING.md](STREAMING.md)。

The `contract` argument may also be a structured futures combo built with
`api.contracts.combo()` (1.7.3+): `api.kbars(combo, start=..., end=...)`.
CLI: `shioaji data kbars --code TXFH6 --combo-with TXFI6 --start ... --end ...`.
HTTP `POST /api/v1/data/kbars` accepts the same actionless `{"legs": [...]}`
contract shape as ticks.

### Python

```python
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")
kbars = api.kbars(
    contract=contract,
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
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")

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
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")

# For futures day session, use a futures contract and switch these settings:
# contract = api.contracts.get("TXFR1")
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

## US Market Data 美股歷史行情與快照

US stocks (`region="US"`, 1.8.0) use the same `api.snapshots()`,
`api.ticks()` and `api.kbars()`. The SDK picks the US path from the contract
(`region="US"` or a US exchange); Taiwan behaviour of all three is unchanged.
美股（1.8.0 起）沿用同一組函式，依合約的 region／交易所走美股路徑；
台股行為不變。

| Rule | US behaviour 美股行為 |
|---|---|
| History 可查區間 | From 2026-10-27. |
| Environment 環境 | The IDC test site has no US data and returns empty results. 測試站 IDC 沒有美股資料，回空。 |
| Time 時間 | `ts` is true **UTC** epoch ns (not Taiwan wall clock). Decode as UTC; do not add or subtract hours by hand. ts 是真正的 UTC。 |
| Numbers 數值 | Market-data values are `float` (not `Decimal`, unlike US orders and accounting). 行情用 float。 |
| Session 時段 | `api.ticks()` and `api.kbars()` return the regular session by default. From 1.8.0 `sessions=` adds pre-market, after-hours and overnight. 預設只回正規盤；1.8.0 起可用 `sessions=` 加入盤前、盤後與夜盤。 |
| Trade date 交易日 | `date` / `trade_date` is the US Eastern trade date. From around 2026-12-06 trade date D covers [D-1 20:00 ET, D 20:00 ET), so overnight trades and volume between 21:00 and 24:00 ET (session 4) belong to the next trade date. Regular-session dates are unchanged. 約 2026-12-06 起美股交易日以美東 20:00 換日（前一日 20:00 到當日 20:00），21:00–24:00 的夜盤成交與量歸下一交易日；正規盤日期不變。 |

```python
import shioaji as sj

aapl = api.contracts.get("AAPL", region="US")
tsmc = api.contracts.get("2330")
if aapl is None or tsmc is None:
    raise LookupError("contract not found")
```

### US Snapshots 美股快照

`api.snapshots()` accepts Taiwan and US contracts mixed (max 2500 in total) and
returns rows in input order: `Snapshot` (`region == "TW"`) for Taiwan,
`UsSnapshot` (`region == "US"`) for US. Dispatch on `region` or `isinstance`.
台美可混在同一次呼叫（合計最多 2500 檔），依輸入順序回傳；用 `region` 或
`isinstance` 分辨。

```python
for snap in api.snapshots([tsmc, aapl]):
    if isinstance(snap, sj.UsSnapshot):          # snap.region == "US"
        print(snap.code, snap.datetime, snap.trade_date, snap.session,
              snap.close, snap.ext_close)
    else:                                        # Snapshot, snap.region == "TW"
        print(snap.code, snap.close)
```

```python
us.ts                # int: UTC epoch ns
us.datetime          # datetime: same instant, tz-aware UTC
us.trade_date        # date: US Eastern trade date, rolls over at 20:00 ET from around 2026-12-06 美東交易日
us.code, us.exchange # str
us.open, us.high, us.low, us.close  # float; pre-market: open/high/low 0, close = previous close
us.reference         # float: reference price 參考價
us.tick_type         # TickType
us.change_price      # float
us.change_rate       # float
us.change_type       # ChangeType
us.average_price     # float
us.volume, us.total_volume          # int
us.amount, us.total_amount          # float
us.yesterday_volume  # int | None
us.volume_ratio      # float | None
us.buy_price, us.sell_price         # float | None
us.buy_volume, us.sell_volume       # int | None
us.ext_close, us.ext_high, us.ext_low  # float | None: extended hours; None without an extended-hours trade
us.session           # UsTradingSession: PreMarket / Regular / AfterHours / Overnight / Unknown (unknown wire values decode as Unknown 未知值解成 Unknown)
us.tradable_status   # int
us.last_price        # float
```

Before the regular session `open`, `high` and `low` are `0` and `close` is the
previous close. 盤前 open/high/low 為 0，close 為前一日收盤價。

### US K-bars 美股 K 棒

`api.kbars(contract, start, end)` returns the same `KBars` type. For US:
美股回傳同樣的 `KBars`：

- `ts` is UTC epoch ns and marks the **bar end** (1-minute bars).
  ts 是 UTC，代表 K 棒結束時間。
- Regular session only: bars from US Eastern 09:31 to 16:00 (13:00 on early-close days).
  只含正規盤（美東 09:31 到 16:00，提早收盤日到 13:00）。
- `Amount` is an estimate. Amount 為估算值。
- One request covers at most 30 days, same as Taiwan. 單次最多 30 天。
- There are no US daily (1D) bars yet. 美股日 K 尚未提供。
- From 1.8.0: `sessions=[...]` (a list of
  `sj.UsTradingSession`) adds other sessions, and US `KBars` gets a `Session`
  column (1 pre-market, 2 regular, 3 after-hours, 4 overnight). Taiwan bars
  have no `Session` key, so `pd.DataFrame({**kbars})` works for both; passing
  `sessions` for a Taiwan contract raises `ShioajiValueError`.
  1.8.0 起：`sessions=[...]`（`sj.UsTradingSession` 清單）
  可加入其他時段，美股 `KBars` 多一欄 `Session`（1 盤前、2 正規、3 盤後、4 夜盤）。
  台股 K 棒沒有 `Session` 鍵，`pd.DataFrame({**kbars})` 兩邊都能用；台股合約傳
  `sessions` 會丟 `ShioajiValueError`。

```python
import pandas as pd

kbars = api.kbars(aapl, start="2026-11-17", end="2026-11-18")
df = pd.DataFrame({**kbars})
df["ts"] = pd.to_datetime(df["ts"], utc=True).dt.tz_convert("America/New_York")
```

```python
# From 1.8.0 1.8.0 起
kbars = api.kbars(
    aapl, start="2026-11-17", end="2026-11-18",
    sessions=[sj.UsTradingSession.PreMarket, sj.UsTradingSession.Regular,
              sj.UsTradingSession.AfterHours],
)
kbars.Session       # List[int]: 1 pre-market, 2 regular, 3 after-hours, 4 overnight
```

### US Ticks 美股逐筆

`api.ticks()` takes the same parameters (`date`, `query_type`, `time_start`,
`time_end`, `last_cnt`) and returns `UsTicks` for a US contract:
美股合約回 `UsTicks`，參數相同但語意如下：

- `date` is the **US Eastern trade date** (from around 2026-12-06 it rolls over at 20:00 ET, see the table above). date 是美東交易日（約 12/06 起美東 20:00 換日）。
- `time_start` / `time_end` (RangeTime) are **UTC** times and may cross UTC
  midnight: `21:00` to `01:00` means US Eastern 16:00 to 20:00 in winter (EST, UTC-5).
  If start is later than end after conversion, the result is empty.
  RangeTime 的起訖是 UTC 時刻，可跨 UTC 午夜；換算後起點晚於終點回空。
- Once overnight trading starts (2026-12-07), times at or after 21:00 ET
  belong to the evening before trade date D, so a range inside D's 20:00 to
  21:00 ET returns no rows (outside the trade day).
  夜盤開始後（2026-12-07 起），美東 21:00 以後的時刻屬於交易日 D 前一晚，
  落在 D 當天美東 20:00–21:00 之間的區間不屬於任何交易日，回空。
  For the same reason a range that starts before 21:00 ET and ends between
  21:00 and 04:00 ET (for example 15:00 to 22:00 ET) counts as reversed and
  returns empty; query the overnight part with its own range.
  同理，起點在美東 21:00 以前、終點在 21:00–04:00 之間（例如美東 15:00–22:00）
  會被當成反向區間而回空；夜盤時段請分開查。
- By default only the regular session is returned (US Eastern 09:30 to the close),
  including closing-auction trades that arrive after the close with
  `session == 3`. Do not filter on `session == 2`.
  預設只回正規盤，含收盤後才到、`session == 3` 的收盤集合競價成交；不要只篩 `session == 2`。
- Rows with the same `ts` are separate trades in trade order; do not dedupe on `ts`.
  同一 ts 多筆是不同成交，順序即成交順序。
- A reply holds at most **100000** rows with no error or flag. If
  `len(ticks.ts) == 100000`, fetch the next page: with `offset` from 1.8.0
  (see below), or with RangeTime from the last `ts` as a UTC time.
  每次最多 10 萬筆，不報錯也沒有旗標；剛好 10 萬筆就續查下一頁：1.8.0 起用
  `offset`（見下方），或從最後一筆 ts 的 UTC 時刻用 RangeTime 續查。

```python
# 2026-11-18 US Eastern 09:30 to 10:00 = 14:30 to 15:00 UTC (EST, UTC-5)
ticks = api.ticks(
    contract=aapl,
    date="2026-11-18",
    query_type=sj.TicksQueryType.RangeTime,
    time_start="14:30:00",
    time_end="15:00:00",
)
ticks.datetime[0]   # tz-aware UTC datetime
```

```python
ticks.ts            # List[int]: UTC epoch ns
ticks.datetime      # List[datetime]: tz-aware UTC
ticks.close         # List[float]
ticks.volume        # List[int]
ticks.bid_price     # List[float | None]
ticks.bid_volume    # List[int | None]
ticks.ask_price     # List[float | None]
ticks.ask_volume    # List[int | None]
ticks.tick_type     # List[int]
ticks.session       # List[int]: 1 pre-market, 2 regular, 3 after-hours, 4 overnight (21:00-04:00 ET, from around 2026-12-06)
ticks.updates_last  # List[bool]
ticks.odd_lot       # List[bool]: odd-lot trade 零股成交
```

#### US Ticks Options 美股逐筆查詢選項

Available from 1.8.0. These are keyword-only,
US-only options; on a Taiwan contract `full=True`, any `sessions` or
`offset > 0` raises `ShioajiValueError` before any request is sent.
1.8.0 起提供。以下皆為只能用關鍵字傳入的美股選項；台股合約傳
`full=True`、任何 `sessions` 或 `offset > 0` 會在送出前丟 `ShioajiValueError`。

| Option 選項 | Default 預設 | Meaning 意義 |
|---|---|---|
| `full` | `False` | `False`: the realtime `QuoteType.Tick` (TICL) definition, the trades that update last price, high/low and inner/outer volume. `True`: every trade, like realtime `QuoteType.TickFull` (odd lots and special-condition trades included). It is about which kinds of trades, not the row count; rows are paged with `offset`. `False` 與即時 `QuoteType.Tick`（TICL）同定義；`True` 是每一筆成交，同即時 `QuoteType.TickFull`（含零股與特殊條件成交）。這是成交種類，不是筆數，筆數用 `offset` 分頁。 |
| `sessions` | `None` (regular only 只有正規盤) | List of `sj.UsTradingSession` (`PreMarket`, `Regular`, `AfterHours`, `Overnight`). 時段清單。 |
| `offset` | `0` | Rows to skip. With `query_type=LastCount` it skips from the tail (the `last_cnt` rows before the last `offset` rows), otherwise from the head. 要略過的筆數；`LastCount` 從尾端算，其他從頭算。 |

```python
ticks = api.ticks(
    contract=aapl,
    date="2026-11-18",
    full=True,
    sessions=[sj.UsTradingSession.PreMarket, sj.UsTradingSession.Regular,
              sj.UsTradingSession.AfterHours],
)
```

Paging with `offset`: start at `offset=0`, add the page length (100000) after
each full page, and stop when a page returns fewer than 100000 rows. Intraday,
page with a head offset (AllDay or RangeTime), not `last_cnt` + `offset`,
because the tail keeps moving as new trades arrive.
用 `offset` 分頁：從 `offset=0` 開始，每拿到滿 10 萬筆就加 100000，回傳少於 10 萬筆即結束。
盤中請用從頭算的 offset（AllDay 或 RangeTime），不要用 `last_cnt` + `offset`，因為尾端會隨新成交一直移動。

```python
import time

LIMIT = 100_000
offset = 0
parts = []
while True:
    page = api.ticks(contract=aapl, date="2026-11-18", full=True, offset=offset)
    parts.append({**page})
    if len(page.ts) < LIMIT:
        break
    offset += LIMIT
    time.sleep(0.2)   # pace the loop; see the usage note below 控制迴圈速度
```

Each page is one quote query and counts toward the quote-query rate limit
(50 requests / 10 sec) and the daily traffic quota listed in
[SKILL.md Rate Limits](../SKILL.md#rate-limits--速率限制). A `full=True` day
of an active stock can take many pages, so pace paging loops, check
`api.usage()` before large backfills, and treat an empty page as a possible
quota hit ([TROUBLESHOOTING.md](TROUBLESHOOTING.md#historical-data-returns-empty-歷史行情回傳空資料)).
每一頁都是一次行情查詢，計入行情查詢速率限制（每 10 秒 50 次）與每日流量額度，見
[SKILL.md 速率限制](../SKILL.md#rate-limits--速率限制)。熱門股 `full=True` 一天可能要很多頁，
分頁迴圈請控制速度，大量回補前先查 `api.usage()`，回空時先懷疑額度用完
（[TROUBLESHOOTING.md](TROUBLESHOOTING.md#historical-data-returns-empty-歷史行情回傳空資料)）。

#### US Ticks Paging on 1.8.0 1.8.0 的分頁方式

On 1.8.0 (no `offset` yet), continue past the 100000-row cap with RangeTime.
The continuation starts at a whole UTC second, so drop the rows of that second from the first part and let
the next reply return them, instead of deduplicating on `ts`:
1.8.0 還沒有 `offset`，超過 10 萬筆時用 RangeTime 分段續查；續查從整秒開始，先把前一段該秒的列去掉，不要用 ts 去重：

```python
import datetime as dt

LIMIT = 100_000
date = "2026-11-18"
parts = []
ticks = api.ticks(contract=aapl, date=date)              # AllDay
while len(ticks.ts) == LIMIT:
    last = dt.datetime.fromtimestamp(ticks.ts[-1] // 1_000_000_000, tz=dt.timezone.utc)
    cut = int(last.timestamp()) * 1_000_000_000          # start of that UTC second
    parts.append({k: [v for v, ts in zip(col, ticks.ts) if ts < cut]
                  for k, col in {**ticks}.items()})
    ticks = api.ticks(
        contract=aapl,
        date=date,
        query_type=sj.TicksQueryType.RangeTime,
        time_start=last.strftime("%H:%M:%S"),
        time_end="23:59:59",                             # UTC; after the closing auction
    )
parts.append({**ticks})
```

### US HTTP 美股 HTTP

HTTP uses the same endpoints. Send `"region": "US"` and the real exchange in
each contract object. HTTP 用同樣的 endpoint，合約要帶 `"region": "US"` 與實際交易所。

```bash
curl -X POST http://localhost:8080/api/v1/data/snapshots \
  -H "Content-Type: application/json" \
  -d '{"contracts": [
        {"security_type": "STK", "exchange": "TSE", "code": "2330"},
        {"security_type": "STK", "region": "US", "exchange": "NASDAQ", "code": "AAPL"}
      ]}'

curl -X POST http://localhost:8080/api/v1/data/ticks \
  -H "Content-Type: application/json" \
  -d '{"contract": {"security_type": "STK", "region": "US", "exchange": "NASDAQ", "code": "AAPL"},
       "date": "2026-11-18", "query_type": "RangeTime",
       "time_start": "14:30:00", "time_end": "15:00:00"}'

# From 1.8.0: every trade, extended sessions, second page
# 1.8.0 起：每一筆成交、延長時段、第二頁
curl -X POST http://localhost:8080/api/v1/data/ticks \
  -H "Content-Type: application/json" \
  -d '{"contract": {"security_type": "STK", "region": "US", "exchange": "NASDAQ", "code": "AAPL"},
       "date": "2026-11-18", "full": true,
       "sessions": ["PreMarket", "Regular", "AfterHours"], "offset": 100000}'
```

- Snapshots: each row carries `region` (`"TW"` / `"US"`), the OpenAPI
  discriminator. US rows have integer `ts` (UTC ns), `trade_date`
  (`YYYY-MM-DD`), `session` as a name (`"PreMarket"`, `"Regular"`,
  `"AfterHours"`, `"Overnight"`, `"Unknown"`) and `null` for missing optional fields.
  Taiwan rows keep `datetime`.
- Ticks: a US reply is `UsTicks` JSON: an integer `ts` column (UTC ns),
  `session` as names, and `null` in the bid/ask columns.
- K-bars: same `KBars` JSON; for US the `datetime` strings have no offset and
  are UTC (bar end).
- From 1.8.0: ticks take `full` (boolean),
  `sessions` (names or ints 1-4) and `offset`; kbars take `sessions` and a US
  reply adds a `Session` column (names). Taiwan requests with these options
  get HTTP 400. 1.8.0 起：ticks 可帶 `full`（布林）、
  `sessions`（名稱或 1–4）與 `offset`；kbars 可帶 `sessions`，美股回覆多 `Session`
  欄（名稱）。台股請求帶這些選項回 HTTP 400。

The CLI `data snapshots` command looks codes up in Taiwan only. From 1.8.0,
`data ticks` and `data kbars` take `--region US` (plus `--full`, `--sessions`,
`--offset`; see [CLI.md](CLI.md#data-ticks)); before that use Python or HTTP for
US data. CLI 的 `data snapshots` 只查台股代碼；1.8.0 起 `data ticks`／`data kbars`
可加 `--region US`（及 `--full`、`--sessions`、`--offset`），之前美股請用 Python 或 HTTP。

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
contract = api.contracts.get("TXFR1")
if contract is None:
    raise LookupError("contract TXFR1 not found")
ticks = api.ticks(
    contract=contract,
    date="2023-01-16",
)

kbars = api.kbars(
    contract=contract,
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
| US stock 美股 | 2026-10-27 |

---

## Credit Enquiries 資券餘額查詢

Query margin and short unit information for stocks.
查詢股票的融資融券餘額資訊。

### Python

```python
contracts = [
    api.contracts.get("2330"),
    api.contracts.get("2890"),
]
if any(contract is None for contract in contracts):
    raise LookupError("credit-enquiry contract not found")

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
    api.contracts.get("2330"),
    api.contracts.get("2317"),
]
if any(contract is None for contract in contracts):
    raise LookupError("short-source contract not found")

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

> Realtime signal push (`subscribe_scanner`: price-limit/rapid-move/volume-burst/simtrade alerts) is different — see [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md).
> 即時訊號推送是另一回事（`subscribe_scanner`：漲跌停／急變／爆量／試撮），見 [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md)。

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
