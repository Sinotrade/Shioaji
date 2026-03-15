# Streaming Market Data 即時行情

This document covers subscribing to real-time market data in Shioaji.
本文件說明如何在 Shioaji 中訂閱即時行情資料。

---

## Overview 概覽

Shioaji provides real-time streaming data via `api.quote.subscribe()`.
Shioaji 透過 `api.quote.subscribe()` 提供即時串流資料。

**Quote Types 報價類型:**
- **Tick**: Trade-by-trade data 逐筆成交
- **BidAsk**: Order book (5 levels) 五檔委託

**Data Classes 資料類別:**

```python
from shioaji import (
    Exchange,       # 交易所
    TickSTKv1,      # Stock tick 股票逐筆
    BidAskSTKv1,    # Stock bidask 股票五檔
    TickFOPv1,      # Futures/Options tick 期貨選擇權逐筆
    BidAskFOPv1,    # Futures/Options bidask 期貨選擇權五檔
)
```

---

## Subscribe 訂閱行情

### Stock Tick 股票 Tick

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Subscribe tick data 訂閱逐筆成交
api.quote.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.Tick
)
```

### Stock BidAsk 股票五檔

```python
api.quote.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.BidAsk
)
```

### Futures Tick 期貨 Tick

```python
api.quote.subscribe(
    api.Contracts.Futures["TXFC0"],
    quote_type=sj.constant.QuoteType.Tick
)
```

### Futures BidAsk 期貨五檔

```python
api.quote.subscribe(
    api.Contracts.Futures["TXFC0"],
    quote_type=sj.constant.QuoteType.BidAsk
)
```

### Intraday Odd Lot 盤中零股

```python
api.quote.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.Tick,
    intraday_odd=True
)
```

---

## Callbacks 行情回調

### Stock Tick Callback 股票 Tick 回調

```python
from shioaji import Exchange, TickSTKv1

# Method 1: Decorator 裝飾器方式
@api.on_tick_stk_v1()
def on_tick(exchange: Exchange, tick: TickSTKv1):
    print(f"Exchange: {exchange}, Code: {tick.code}, Close: {tick.close}")

# Method 2: Set callback 設定回調
api.quote.set_on_tick_stk_v1_callback(on_tick)
```

### Stock BidAsk Callback 股票五檔回調

```python
from shioaji import Exchange, BidAskSTKv1

@api.on_bidask_stk_v1()
def on_bidask(exchange: Exchange, bidask: BidAskSTKv1):
    print(f"Code: {bidask.code}, Bid: {bidask.bid_price[0]}, Ask: {bidask.ask_price[0]}")

# Or 或
api.quote.set_on_bidask_stk_v1_callback(on_bidask)
```

### Futures/Options Tick Callback 期貨選擇權 Tick 回調

```python
from shioaji import Exchange, TickFOPv1

@api.on_tick_fop_v1()
def on_tick(exchange: Exchange, tick: TickFOPv1):
    print(f"Code: {tick.code}, Close: {tick.close}")

# Or 或
api.quote.set_on_tick_fop_v1_callback(on_tick)
```

### Futures/Options BidAsk Callback 期貨選擇權五檔回調

```python
from shioaji import Exchange, BidAskFOPv1

@api.on_bidask_fop_v1()
def on_bidask(exchange: Exchange, bidask: BidAskFOPv1):
    print(f"Code: {bidask.code}, Bid: {bidask.bid_price[0]}")

# Or 或
api.quote.set_on_bidask_fop_v1_callback(on_bidask)
```

---

## TickSTKv1 Attributes 股票 Tick 屬性

```python
from shioaji import Exchange, TickSTKv1
from datetime import datetime
from decimal import Decimal

@api.on_tick_stk_v1()
def on_tick(exchange: Exchange, tick: TickSTKv1):
    # Basic info 基本資訊
    tick.code              # str: Stock code 股票代碼
    tick.datetime          # datetime: Timestamp 時間戳

    # Price data 價格資料
    tick.open              # Decimal: Open price 開盤價
    tick.high              # Decimal: High price 最高價
    tick.low               # Decimal: Low price 最低價
    tick.close             # Decimal: Last price 最新價
    tick.avg_price         # Decimal: Average price 均價

    # Volume data 量能資料
    tick.volume            # int: Tick volume 單筆成交量
    tick.total_volume      # int: Total volume 總成交量
    tick.amount            # Decimal: Tick amount 單筆成交金額
    tick.total_amount      # Decimal: Total amount 總成交金額

    # Tick type 成交類型
    tick.tick_type         # int: 1=Buy, 2=Sell, 0=Unknown

    # Change data 漲跌資料
    tick.chg_type          # int: Change type 漲跌類型
    tick.price_chg         # Decimal: Price change 漲跌
    tick.pct_chg           # Decimal: Percent change % 漲跌幅

    # Aggregated 彙總資料
    tick.bid_side_total_vol  # int: Total bid volume 買方總量
    tick.ask_side_total_vol  # int: Total ask volume 賣方總量
    tick.bid_side_total_cnt  # int: Total bid count 買方筆數
    tick.ask_side_total_cnt  # int: Total ask count 賣方筆數
```

---

## BidAskSTKv1 Attributes 股票五檔屬性

```python
from shioaji import Exchange, BidAskSTKv1
from typing import List
from decimal import Decimal

@api.on_bidask_stk_v1()
def on_bidask(exchange: Exchange, bidask: BidAskSTKv1):
    bidask.code            # str: Stock code 股票代碼
    bidask.datetime        # datetime: Timestamp 時間戳

    # 5 levels of bid/ask 五檔買賣價量
    bidask.bid_price       # List[Decimal]: [買1, 買2, 買3, 買4, 買5]
    bidask.bid_volume      # List[int]: [買量1, 買量2, ...]
    bidask.ask_price       # List[Decimal]: [賣1, 賣2, 賣3, 賣4, 賣5]
    bidask.ask_volume      # List[int]: [賣量1, 賣量2, ...]

    # Volume change 量變化
    bidask.diff_bid_vol    # List[int]: Bid volume changes 買量變化
    bidask.diff_ask_vol    # List[int]: Ask volume changes 賣量變化

    # Example: Spread 範例：價差
    spread = bidask.ask_price[0] - bidask.bid_price[0]
```

---

## TickFOPv1 Attributes 期貨選擇權 Tick 屬性

```python
from shioaji import Exchange, TickFOPv1

@api.on_tick_fop_v1()
def on_tick(exchange: Exchange, tick: TickFOPv1):
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

---

## BidAskFOPv1 Attributes 期貨選擇權五檔屬性

```python
from shioaji import Exchange, BidAskFOPv1

@api.on_bidask_fop_v1()
def on_bidask(exchange: Exchange, bidask: BidAskFOPv1):
    bidask.code            # str: Contract code 合約代碼
    bidask.datetime        # datetime: Timestamp 時間戳
    bidask.bid_price       # List[Decimal]: Bid prices (5 levels)
    bidask.bid_volume      # List[int]: Bid volumes (5 levels)
    bidask.ask_price       # List[Decimal]: Ask prices (5 levels)
    bidask.ask_volume      # List[int]: Ask volumes (5 levels)
```

---

## Unsubscribe 取消訂閱

```python
api.quote.unsubscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.Tick
)

api.quote.unsubscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.BidAsk
)
```

---

## Event Callbacks 事件回調

```python
@api.quote.on_event
def event_callback(resp_code: int, event_code: int, info: str, event: str):
    print(f"Event Code: {event_code}, Info: {info}")
```

| Event Code | Description 說明 |
|------------|------------------|
| 0 | Heartbeat 心跳 |
| 1 | Connected 連線建立 |
| 2 | Disconnected 斷線 |
| 3 | Reconnecting 重新連線中 |
| 4 | Reconnected 重新連線成功 |
| 16 | Subscribe success 訂閱成功 |
| 17 | Unsubscribe success 取消訂閱成功 |

---

## Quote Manager with Polars 使用 Polars 的行情管理器

Recommended pattern using Polars for high-performance data processing:
推薦使用 Polars 進行高效能資料處理：

```python
import polars as pl
from shioaji import Exchange, TickSTKv1
from typing import List

class QuoteManager:
    def __init__(self):
        self.ticks: List[dict] = []

    def on_tick(self, exchange: Exchange, tick: TickSTKv1):
        self.ticks.append({
            "code": tick.code,
            "datetime": tick.datetime,
            "price": float(tick.close),
            "volume": tick.volume,
            "total_volume": tick.total_volume,
            "tick_type": tick.tick_type,
        })

    def get_df(self) -> pl.DataFrame:
        return pl.DataFrame(self.ticks)

    def get_kbar(self, unit: str = "1m") -> pl.DataFrame:
        """Generate K-bar from ticks 從 tick 產生 K 棒"""
        df = self.get_df()
        return df.group_by(
            pl.col("datetime").dt.truncate(unit),
            pl.col("code"),
        ).agg(
            pl.col("price").first().alias("open"),
            pl.col("price").max().alias("high"),
            pl.col("price").min().alias("low"),
            pl.col("price").last().alias("close"),
            pl.col("volume").sum().alias("volume"),
        )

# Usage 使用方式
manager = QuoteManager()

@api.on_tick_stk_v1()
def on_tick(exchange: Exchange, tick: TickSTKv1):
    manager.on_tick(exchange, tick)

# Get 1-minute K-bars 取得 1 分鐘 K 棒
kbars = manager.get_kbar("1m")
```

### Technical Indicators with Polars 使用 Polars 計算技術指標

Use `over("code")` to calculate indicators separately for each stock:
使用 `over("code")` 讓每檔商品分開計算指標：

```python
def add_indicators(df: pl.DataFrame, exprs: List[pl.Expr] = []) -> pl.DataFrame:
    """Add technical indicators 加入技術指標"""
    base_exprs = [
        # SMA 簡單移動平均 (per stock 每檔分開計算)
        pl.col("close").rolling_mean(window_size=5).over("code").alias("sma5"),
        pl.col("close").rolling_mean(window_size=20).over("code").alias("sma20"),

        # EMA 指數移動平均 (per stock 每檔分開計算)
        pl.col("close").ewm_mean(span=12).over("code").alias("ema12"),
        pl.col("close").ewm_mean(span=26).over("code").alias("ema26"),
    ]
    return df.with_columns(base_exprs + exprs)

# MACD (per stock 每檔分開計算)
def macd(df: pl.DataFrame) -> pl.DataFrame:
    return df.with_columns([
        (pl.col("ema12") - pl.col("ema26")).alias("macd"),
        (pl.col("ema12") - pl.col("ema26")).ewm_mean(span=9).over("code").alias("signal"),
    ])
```

---

## Multiple Subscriptions 多重訂閱

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
    api.Contracts.Stocks["2454"],
]

for contract in contracts:
    api.quote.subscribe(contract, quote_type=sj.constant.QuoteType.Tick)
```

---

## Best Practices 最佳實踐

### 1. Handle Disconnections 處理斷線

```python
@api.quote.on_event
def on_event(resp_code: int, event_code: int, info: str, event: str):
    if event_code == 2:  # Disconnected
        print("Disconnected...")
    elif event_code == 4:  # Reconnected
        resubscribe_all()
```

### 2. Rate Limiting 速率限制

```python
# Limit: 50 requests / 5 seconds
# 限制：50 次 / 5 秒

import time

for i, contract in enumerate(contracts):
    api.quote.subscribe(contract, quote_type=sj.constant.QuoteType.Tick)
    if (i + 1) % 50 == 0:
        time.sleep(5)
```

### 3. Memory Management 記憶體管理

```python
from collections import deque
from shioaji import Exchange, TickSTKv1

class QuoteBuffer:
    def __init__(self, max_size: int = 10000):
        self.buffer = deque(maxlen=max_size)

    def add(self, exchange: Exchange, tick: TickSTKv1):
        self.buffer.append({
            "code": tick.code,
            "datetime": tick.datetime,
            "price": float(tick.close),
            "volume": tick.volume,
        })
```

---

## Reference 參考資料

- Demo project 範例專案: https://github.com/Sinotrade/sj-trading-demo
- Official docs 官方文檔: https://sinotrade.github.io/tutor/market_data/streaming/
