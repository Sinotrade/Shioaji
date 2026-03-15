# Market Data 市場資料

This document covers historical data, snapshots, credit enquiries, short stock sources, scanners, and disposition/attention stocks.
本文件說明歷史資料查詢、快照、資券餘額查詢、券源查詢、掃描器排行及處置/注意股。

---

## Historical Ticks 歷史 Tick 資料

Query historical tick data by date, time range, or last count.
依日期、時間區間或筆數查詢歷史逐筆資料。

### By Date 依日期

```python
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2023-01-16"
)
```

### By Time Range 依時間區間

```python
import shioaji as sj

ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2023-01-16",
    query_type=sj.constant.TicksQueryType.RangeTime,
    time_start="09:00:00",
    time_end="09:20:01"
)
```

### Last Count 最後 N 筆

```python
ticks = api.ticks(
    contract=api.Contracts.Stocks["2330"],
    date="2023-01-16",
    query_type=sj.constant.TicksQueryType.LastCount,
    last_cnt=100,
)
```

### Ticks Attributes Tick 屬性

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

```python
kbars = api.kbars(
    contract=api.Contracts.Stocks["2330"],
    start="2023-01-15",
    end="2023-01-16",
)
```

### KBars Attributes K 棒屬性

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

## Continuous Futures 連續期貨

For historical data of expired futures, use continuous contracts `R1` (near-month) and `R2` (next-to-near-month).
查詢已過期期貨的歷史資料，使用連續合約 `R1`（近月）和 `R2`（次近月）。

```python
# Continuous near-month futures 連續近月期貨
ticks = api.ticks(
    contract=api.Contracts.Futures.TXF.TXFR1,
    date="2023-01-16"
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

## Snapshot 即時快照

Get current snapshot for multiple contracts (max 500 per request).
取得多個合約的當前快照（每次最多 500 個）。

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
]

snapshots = api.snapshots(contracts)
```

### Snapshot Attributes 快照屬性

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

### Convert to Polars 轉換為 Polars

```python
import polars as pl

# Use BaseModel.dict() to convert 使用 BaseModel.dict() 轉換
df = pl.DataFrame([s.dict() for s in snapshots])
```

---

## Credit Enquiries 資券餘額查詢

Query margin and short unit information for stocks.
查詢股票的融資融券餘額資訊。

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2890"],
]

credit_enquires = api.credit_enquires(contracts)
```

### CreditEnquire Attributes 資券餘額屬性

```python
enquire.update_time   # str: Update time 更新時間
enquire.system        # str: System code 系統代碼
enquire.stock_id      # str: Stock code 股票代碼
enquire.margin_unit   # int: Margin units 融資餘額
enquire.short_unit    # int: Short units 融券餘額
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

# Use BaseModel.dict() to convert 使用 BaseModel.dict() 轉換
df = pl.DataFrame([c.dict() for c in credit_enquires])
```

---

## Short Stock Sources 券源查詢

Query available short stock sources (借券來源).
查詢可借券數量。

```python
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
]

short_sources = api.short_stock_sources(contracts)
```

### ShortStockSource Attributes 券源屬性

```python
source.code               # str: Stock code 股票代碼
source.short_stock_source # int: Available shares 可借券數量
source.ts                 # int: Timestamp 時間戳
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

# Use BaseModel.dict() to convert 使用 BaseModel.dict() 轉換
df = pl.DataFrame([s.dict() for s in short_sources]).with_columns(
    pl.col("ts").cast(pl.Datetime("ns"))
)
```

---

## Scanners 掃描器排行

Get market rankings by various criteria.
依各種條件取得市場排行。

### Scanner Types 掃描器類型

```python
import shioaji as sj

sj.constant.ScannerType.ChangePercentRank  # 漲跌幅排行
sj.constant.ScannerType.ChangePriceRank    # 漲跌價排行
sj.constant.ScannerType.DayRangeRank       # 振幅排行
sj.constant.ScannerType.VolumeRank         # 成交量排行
sj.constant.ScannerType.AmountRank         # 成交金額排行
```

### Query Scanners 查詢排行

```python
# Top 10 gainers 漲幅前 10 名
scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.ChangePercentRank,
    ascending=False,  # False = descending 由大到小
    count=10,
)

# Top 10 losers 跌幅前 10 名
scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.ChangePercentRank,
    ascending=True,  # True = ascending 由小到大
    count=10,
)

# Top volume 成交量排行
scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.VolumeRank,
    ascending=False,
    count=10,
)
```

### Scanner Attributes 掃描器屬性

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

### Convert to Polars 轉換為 Polars

```python
import polars as pl

scanners = api.scanners(
    scanner_type=sj.constant.ScannerType.ChangePercentRank,
    count=50,
)

# Use BaseModel.dict() to convert 使用 BaseModel.dict() 轉換
df = pl.DataFrame([s.dict() for s in scanners])

# Filter high volume ratio 篩選量比高的
high_volume = df.filter(pl.col("volume_ratio") > 2)
```

---

## Disposition Stocks 處置股

Query stocks under trading restrictions (處置股).
查詢受交易限制的處置股清單。

```python
punish = api.punish()
```

### Punish Attributes 處置股屬性

```python
punish.code            # List[str]: Stock codes 股票代碼
punish.start_date      # List[date]: Disposition start date 處置開始日
punish.end_date        # List[date]: Disposition end date 處置結束日
punish.updated_at      # List[datetime]: Updated time 更新時間
punish.interval        # List[str]: Matching interval 撮合間隔 (e.g., "5分鐘")
punish.unit_limit      # List[float]: Single order limit % 單筆限額
punish.total_limit     # List[float]: Daily order limit % 每日限額
punish.description     # List[str]: Description 說明
punish.announced_date  # List[date]: Announced date 公告日
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

# Punish returns single object with list attributes
# Punish 回傳單一物件，屬性為 list
df = pl.DataFrame(punish.dict())
```

---

## Attention Stocks 注意股

Query stocks under attention (注意股).
查詢受注意的股票清單。

```python
notice = api.notice()
```

### Notice Attributes 注意股屬性

```python
notice.code            # List[str]: Stock codes 股票代碼
notice.updated_at      # List[datetime]: Updated time 更新時間
notice.close           # List[float]: Close price 收盤價
notice.reason          # List[str]: Attention reason 注意原因
notice.announced_date  # List[date]: Announced date 公告日
```

### Convert to Polars 轉換為 Polars

```python
import polars as pl

# Notice returns single object with list attributes
# Notice 回傳單一物件，屬性為 list
df = pl.DataFrame(notice.dict())
```

---

## Reference 參考資料

- Historical data 歷史資料: https://sinotrade.github.io/tutor/market_data/historical/
- Snapshot 快照: https://sinotrade.github.io/tutor/market_data/snapshot/
- Credit enquiries 資券餘額: https://sinotrade.github.io/tutor/market_data/credit_enquires/
- Short stock sources 券源: https://sinotrade.github.io/tutor/market_data/short_stock_source/
- Scanners 掃描器: https://sinotrade.github.io/tutor/market_data/scanners/
- Disposition/Attention 處置/注意股: https://sinotrade.github.io/tutor/market_data/disposition_attention/
