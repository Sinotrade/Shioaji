# Accounting 帳務查詢

This document covers account balance, margin, positions, and P&L queries.
本文件說明帳戶餘額、保證金、持倉和損益查詢。

---

## Overview 概覽

| Function 函數 | Description 說明 |
|--------------|------------------|
| `account_balance()` | Stock account balance 股票帳戶餘額 |
| `margin()` | Futures margin info 期貨保證金 |
| `list_positions()` | Unrealized positions 未實現持倉 |
| `list_position_detail()` | Position details 持倉明細 |
| `list_profit_loss()` | Realized P&L 已實現損益 |
| `settlements()` | Settlement schedule 交割資訊 |

---

## Bank Balance 銀行餘額

### Stock Account Balance 股票帳戶餘額

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Query balance (default: stock_account) 查詢餘額（預設：股票帳戶）
balance = api.account_balance()

# Query with specific account 指定帳戶查詢
balance = api.account_balance(account=api.stock_account)
```

### account_balance Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `account` | `Account` | Account to query (Default: stock_account) 查詢帳戶（預設：股票帳戶）|
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

### AccountBalance Attributes 餘額屬性

```python
balance.date           # str: Query date 查詢日期
balance.acc_balance    # Decimal: Available funds 可用餘額
balance.status         # str: Status 狀態
```

---

## Margin 保證金查詢

### Futures Margin 期貨保證金

```python
margin = api.margin(api.futopt_account)
```

### Margin Attributes 保證金屬性

```python
margin.yesterday_balance    # Decimal: Yesterday balance 昨日餘額
margin.today_balance        # Decimal: Today balance 今日餘額
margin.deposit_withdrawal   # Decimal: Deposit/withdrawal 出入金
margin.fee                  # Decimal: Fees 手續費
margin.tax                  # Decimal: Tax 稅金
margin.initial_margin       # Decimal: Initial margin 原始保證金
margin.maintenance_margin   # Decimal: Maintenance margin 維持保證金
margin.margin_call          # Decimal: Margin call 追繳金額
margin.available_margin     # Decimal: Available margin 可用保證金
margin.risk_indicator       # Decimal: Risk indicator 風險指標

# P&L related 損益相關
margin.future_open_position     # Decimal: Futures open position P&L 期貨未平倉損益
margin.option_open_position     # Decimal: Options open position P&L 選擇權未平倉損益
margin.option_settle_profitloss # Decimal: Options settlement P&L 選擇權結算損益
margin.future_settle_profitloss # Decimal: Futures settlement P&L 期貨結算損益
```

---

## Positions 持倉查詢

### Stock Positions 股票持倉

```python
from shioaji import StockPosition

positions = api.list_positions(api.stock_account)

for pos in positions:
    print(f"Code: {pos.code}, Qty: {pos.quantity}, P&L: {pos.pnl}")
```

### StockPosition Attributes 股票持倉屬性

```python
pos.id              # str: Position ID 持倉 ID
pos.code            # str: Stock code 股票代碼
pos.direction       # str: Long/Short 多空方向
pos.quantity        # int: Holding quantity 持有數量
pos.price           # Decimal: Average cost 平均成本
pos.last_price      # Decimal: Current price 現價
pos.pnl             # Decimal: Unrealized P&L 未實現損益
pos.yd_quantity     # int: Yesterday quantity 昨日數量
pos.cond            # str: Order condition 交易條件 (Cash/MarginTrading/ShortSelling)
pos.margin_purchase_amount  # Decimal: Margin amount 融資金額
pos.collateral      # Decimal: Collateral 擔保品
pos.short_sale_margin       # Decimal: Short margin 融券保證金
```

### Futures/Options Positions 期貨選擇權持倉

```python
from shioaji import FuturePosition

positions = api.list_positions(api.futopt_account)

for pos in positions:
    print(f"Code: {pos.code}, Qty: {pos.quantity}, P&L: {pos.pnl}")
```

### FuturePosition Attributes 期貨持倉屬性

```python
pos.id              # str: Position ID 持倉 ID
pos.code            # str: Contract code 合約代碼
pos.direction       # str: Long/Short 多空方向
pos.quantity        # int: Holding quantity 持有口數
pos.price           # Decimal: Average cost 平均成本
pos.last_price      # Decimal: Current price 現價
pos.pnl             # Decimal: Unrealized P&L 未實現損益
```

---

## Position Detail 持倉明細

### Get Position Detail 取得持倉明細

```python
from shioaji import StockPositionDetail

# Get all position details 取得所有持倉明細
details = api.list_position_detail(api.stock_account)

# Get specific position detail 取得特定持倉明細
detail = api.list_position_detail(api.stock_account, detail_id="position_id")
```

### StockPositionDetail Attributes 股票持倉明細屬性

```python
detail.id              # str: Detail ID 明細 ID
detail.code            # str: Stock code 股票代碼
detail.quantity        # int: Quantity 數量
detail.cost_price      # Decimal: Cost price 成本價
detail.entry_date      # str: Entry date 進場日期
detail.fee             # Decimal: Fee 手續費
detail.cond            # str: Order condition 交易條件
```

### FuturePositionDetail Attributes 期貨持倉明細屬性

```python
detail.id              # str: Detail ID 明細 ID
detail.code            # str: Contract code 合約代碼
detail.quantity        # int: Quantity 口數
detail.cost_price      # Decimal: Cost price 成本價
detail.entry_date      # str: Entry date 進場日期
detail.fee             # Decimal: Fee 手續費
```

---

## Profit & Loss 損益查詢

### Realized P&L 已實現損益

```python
from shioaji import ProfitLoss

# Query by date range 依日期範圍查詢
pnl_list = api.list_profit_loss(
    api.stock_account,
    begin_date="2024-01-01",
    end_date="2024-01-31"
)

for pnl in pnl_list:
    print(f"Code: {pnl.code}, P&L: {pnl.pnl}")
```

### ProfitLoss Attributes 損益屬性

```python
pnl.id            # str: P&L ID 損益 ID
pnl.code          # str: Stock/Contract code 代碼
pnl.quantity      # int: Quantity 數量
pnl.buy_price     # Decimal: Buy price 買進價
pnl.sell_price    # Decimal: Sell price 賣出價
pnl.pnl           # Decimal: Profit/Loss 損益
pnl.pr_ratio      # Decimal: Profit ratio % 報酬率
pnl.cond          # str: Order condition 交易條件
pnl.fee           # Decimal: Fee 手續費
pnl.tax           # Decimal: Tax 稅金
pnl.trade_date    # str: Trade date 交易日期
pnl.settle_date   # str: Settlement date 交割日期
```

### P&L Summary 損益彙總

```python
from shioaji import ProfitLossSummaryTotal

summary = api.list_profit_loss_summary(
    api.stock_account,
    begin_date="2024-01-01",
    end_date="2024-01-31"
)

print(f"Total P&L: {summary.total_pnl}")
```

### ProfitLossSummaryTotal Attributes 損益彙總屬性

```python
summary.total_pnl        # Decimal: Total P&L 總損益
summary.total_cost       # Decimal: Total cost 總成本
summary.total_revenue    # Decimal: Total revenue 總收入
summary.total_fee        # Decimal: Total fee 總手續費
summary.total_tax        # Decimal: Total tax 總稅金
```

---

## Settlements 交割資訊

### Query Settlements 查詢交割

```python
from shioaji import SettlementV1

settlements = api.settlements(api.stock_account)

for settle in settlements:
    print(f"Date: {settle.date}, Amount: {settle.amount}")
```

### SettlementV1 Attributes 交割屬性

```python
settle.date           # str: Settlement date (T+n) 交割日期
settle.amount         # Decimal: Settlement amount 交割金額
settle.t_money        # Decimal: T-day amount T 日金額
settle.t1_money       # Decimal: T+1 amount T+1 日金額
settle.t2_money       # Decimal: T+2 amount T+2 日金額
```

---

## Trading Limits 交易額度

Query available trading limits for stock account.
查詢股票帳戶的交易額度。

Note: Available on trading days from 8:30 to 15:00.
注意：交易日 8:30 至 15:00 可查詢。

### Query Trading Limits 查詢交易額度

```python
limits = api.trading_limits(api.stock_account)

print(f"Trading Limit: {limits.trading_limit}")
print(f"Trading Used: {limits.trading_used}")
print(f"Trading Available: {limits.trading_available}")
```

### TradingLimits Attributes 交易額度屬性

```python
limits.status             # FetchStatus: Fetch status 取得狀態
limits.trading_limit      # int: Trading limit 交易額度上限
limits.trading_used       # int: Trading used 已使用額度
limits.trading_available  # int: Trading available 可用額度

# Margin trading 融資
limits.margin_limit       # int: Margin limit 融資額度上限
limits.margin_used        # int: Margin used 已使用融資
limits.margin_available   # int: Margin available 可用融資

# Short selling 融券
limits.short_limit        # int: Short limit 融券額度上限
limits.short_used         # int: Short used 已使用融券
limits.short_available    # int: Short available 可用融券
```

### Check Available Margin 檢查可用額度

```python
limits = api.trading_limits(api.stock_account)

if limits.trading_available >= order_amount:
    print("Sufficient trading limit")
else:
    print(f"Insufficient! Available: {limits.trading_available}")
```

---

## Query with Polars 使用 Polars 查詢

### Positions to DataFrame 持倉轉 DataFrame

```python
import polars as pl
from shioaji import StockPosition

positions = api.list_positions(api.stock_account)

df = pl.DataFrame([
    {
        "code": pos.code,
        "quantity": pos.quantity,
        "price": float(pos.price),
        "last_price": float(pos.last_price),
        "pnl": float(pos.pnl),
    }
    for pos in positions
])

# Calculate total P&L 計算總損益
total_pnl = df.select(pl.col("pnl").sum()).item()
```

### P&L Analysis 損益分析

```python
pnl_list = api.list_profit_loss(
    api.stock_account,
    begin_date="2024-01-01",
    end_date="2024-12-31"
)

df = pl.DataFrame([
    {
        "code": pnl.code,
        "pnl": float(pnl.pnl),
        "pr_ratio": float(pnl.pr_ratio),
        "trade_date": pnl.trade_date,
    }
    for pnl in pnl_list
])

# Group by stock 依股票分組
by_stock = df.group_by("code").agg([
    pl.col("pnl").sum().alias("total_pnl"),
    pl.col("pnl").count().alias("trade_count"),
    pl.col("pr_ratio").mean().alias("avg_return"),
])
```

---

## Rate Limits 速率限制

```python
# Accounting query limit: 25 requests / 5 seconds
# 帳務查詢限制：25 次 / 5 秒

import time

# If making multiple queries 如果需要多次查詢
for account in accounts:
    balance = api.account_balance(account)
    time.sleep(0.2)  # Respect rate limit 遵守速率限制
```

---

## Best Practices 最佳實踐

### 1. Cache Positions 快取持倉

```python
class PositionCache:
    def __init__(self, api):
        self.api = api
        self._positions = None
        self._last_update = None

    def get_positions(self, force_refresh: bool = False):
        import time
        now = time.time()

        if force_refresh or self._positions is None or (now - self._last_update) > 60:
            self._positions = self.api.list_positions(self.api.stock_account)
            self._last_update = now

        return self._positions
```

### 2. Error Handling 錯誤處理

```python
try:
    positions = api.list_positions(api.stock_account)
except Exception as e:
    print(f"Failed to query positions: {e}")
    positions = []
```

---

## Reference 參考資料

- Official docs 官方文檔: https://sinotrade.github.io/tutor/accounting/
