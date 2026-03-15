# Advanced Features 進階功能

This document covers non-blocking mode, stop orders, historical data, and scanners.
本文件說明非阻塞模式、觸價委託、歷史數據和掃描器。

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
# Set timeout=0 for non-blocking 設定 timeout=0 為非阻塞
trade = api.place_order(contract, order, timeout=0)
# Returns immediately with Inactive status
# 立即返回，狀態為 Inactive
```

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
from shioaji import Exchange, TickSTKv1

# Create message queue 建立訊息佇列
msg_queue = defaultdict(deque)

# Set context 設定 context
api.set_context(msg_queue)
```

### Use bind=True 使用 bind=True

```python
# Method 1: Decorator with bind=True
# 方法一：使用 bind=True 裝飾器
@api.on_tick_stk_v1(bind=True)
def quote_callback(self, exchange: Exchange, tick: TickSTKv1):
    # 'self' is the context (msg_queue)
    # 'self' 就是 context (msg_queue)
    self[tick.code].append(tick)

# Method 2: Traditional way
# 方法二：傳統方式
def quote_callback(self, exchange: Exchange, tick: TickSTKv1):
    self[tick.code].append(tick)

api.quote.set_on_tick_stk_v1_callback(quote_callback, bind=True)
```

### Push to Redis Stream 推送到 Redis

```python
import redis
import json
from shioaji import Exchange, TickFOPv1

# Redis connection Redis 連線
r = redis.Redis(host='localhost', port=6379, db=0)

# Set Redis as context 設定 Redis 為 context
api.set_context(r)

@api.on_tick_fop_v1(bind=True)
def quote_callback(self, exchange: Exchange, tick: TickFOPv1):
    channel = f"Q:{tick.code}"
    # Push to Redis stream 推送到 Redis stream
    self.xadd(channel, {'tick': json.dumps(tick.to_dict(raw=True))})
```

### Quote Manager Pattern 報價管理器模式

```python
from typing import List
import polars as pl
from shioaji import TickSTKv1, Exchange

class QuoteManager:
    def __init__(self, api):
        self.api = api
        self.ticks: List[TickSTKv1] = []
        # Register callback 註冊回調
        api.quote.set_on_tick_stk_v1_callback(self._on_tick)

    def _on_tick(self, exchange: Exchange, tick: TickSTKv1):
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
api.quote.subscribe(api.Contracts.Stocks["2330"], "tick")

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
from shioaji import Exchange, TickFOPv1
from typing import List, Dict, Any

class StopOrderExecutor:
    def __init__(self, api):
        self.api = api
        self._stop_orders: Dict[str, List[Dict[str, Any]]] = {}

    def on_tick(self, exchange: Exchange, tick: TickFOPv1):
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
                self.api.place_order(
                    stop_order["contract"],
                    stop_order["pending_order"]
                )
                stop_order["executed"] = True
                print(f"Stop order triggered: {code} @ {price}")

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

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Create stop order executor 建立觸價執行器
soe = StopOrderExecutor(api)

# Define contract and order 定義合約和訂單
contract = api.Contracts.Futures["TXFC0"]
order = api.Order(
    action=sj.constant.Action.Buy,
    price=18000,
    quantity=1,
    price_type=sj.constant.FuturesPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    account=api.futopt_account,
)

# Add stop order (trigger when price >= 18005)
# 新增觸價委託（價格 >= 18005 時觸發）
soe.add_stop_order(contract=contract, stop_price=18005, order=order)

# Bind callback with context 綁定回調與 context
api.set_context(soe)

@api.on_tick_fop_v1(bind=True)
def on_tick(self, exchange: Exchange, tick: TickFOPv1):
    self.on_tick(exchange, tick)

# Subscribe to quotes 訂閱行情
api.quote.subscribe(contract, quote_type=sj.constant.QuoteType.Tick)
```

---

## Historical Data 歷史數據

### Ticks 逐筆成交

```python
# Full day ticks 全天 Ticks
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2024-01-16"
)

# Time range 時間區段
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2024-01-16",
    query_type=sj.constant.TicksQueryType.RangeTime,
    time_start="09:00:00",
    time_end="09:30:00"
)

# Last N ticks 最後 N 筆
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    query_type=sj.constant.TicksQueryType.LastCount,
    last_cnt=100
)
```

### Ticks Attributes Ticks 屬性

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
sj.constant.ScannerType.ChangePercentRank

# By change price 依漲跌價
sj.constant.ScannerType.ChangePriceRank

# By day range (high-low) 依當日振幅
sj.constant.ScannerType.DayRangeRank

# By volume 依成交量
sj.constant.ScannerType.VolumeRank

# By amount 依成交金額
sj.constant.ScannerType.AmountRank
```

### Query Scanners 查詢掃描器

```python
# Top 10 gainers 漲幅前 10 名
scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.ChangePercentRank,
    ascending=False,  # Descending 由大到小
    count=10
)

# Top 10 losers 跌幅前 10 名
scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.ChangePercentRank,
    ascending=True,  # Ascending 由小到大
    count=10
)

# Top 10 by volume 成交量前 10 名
scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.VolumeRank,
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
snap.yesterday_volume # int: Yesterday volume 昨日成交量
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

## Best Practices 最佳實踐

### 1. Use Non-blocking for Batch Orders 批量下單使用非阻塞

```python
orders = [...]  # Multiple orders
trades = []

for contract, order in orders:
    trade = api.place_order(contract, order, timeout=0)
    trades.append(trade)

# Handle results in callback 在回調中處理結果
```

### 2. Minimize Computation in Callbacks 回調中最小化計算

```python
from queue import Queue

tick_queue = Queue()

@api.on_tick_stk_v1()
def on_tick(exchange, tick):
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

---

## Reference 參考資料

- Demo project 範例專案: https://github.com/Sinotrade/sj-trading-demo
- Official docs 官方文檔: https://sinotrade.github.io/
