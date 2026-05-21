# Accounting 帳務查詢

This document covers account balance, margin, positions, profit/loss, settlements, and trading limits in rshioaji.
本文件說明 rshioaji 中的帳戶餘額、保證金、持倉、損益、交割及交易額度查詢。

See [HTTP_API.md](HTTP_API.md) for full endpoint details.

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Account Balance 帳戶餘額](#account-balance-帳戶餘額)
- [Margin 保證金查詢](#margin-保證金查詢)
- [Positions 持倉查詢](#positions-持倉查詢)
- [Position Detail 持倉明細](#position-detail-持倉明細)
- [Profit & Loss 損益查詢](#profit--loss-損益查詢)
- [P&L Detail 損益明細](#pl-detail-損益明細)
- [P&L Summary 損益彙總](#pl-summary-損益彙總)
- [Settlements (Legacy) 交割資訊（舊版）](#settlements-legacy-交割資訊舊版)
- [Settlements (New) 交割資訊（新版）](#settlements-new-交割資訊新版)
- [Trading Limits 交易額度](#trading-limits-交易額度)
- [Simulation Mode Notes 模擬模式注意事項](#simulation-mode-notes-模擬模式注意事項)

---

## Overview 概覽

| Python Method 方法 | Description 說明 | HTTP Path |
|---------------------|------------------|-----------|
| `account_balance()` | Stock account balance 股票帳戶餘額 | `POST /api/v1/portfolio/account_balance` |
| `margin()` | Futures margin info 期貨保證金 | `POST /api/v1/portfolio/margin` |
| `list_positions()` | Unrealized positions 未實現持倉 | `POST /api/v1/portfolio/position_unit` |
| `list_position_detail()` | Position details 持倉明細 | `POST /api/v1/portfolio/position_detail` |
| `list_profit_loss()` | Realized P&L 已實現損益 | `POST /api/v1/portfolio/profit_loss` |
| `list_profit_loss_detail()` | P&L details 損益明細 | `POST /api/v1/portfolio/profit_loss_detail` |
| `list_profit_loss_summary()` | P&L summary 損益彙總 | `POST /api/v1/portfolio/profitloss_sum` |
| `list_settlements()` | Settlement (legacy format) 交割（舊格式） | `POST /api/v1/portfolio/settlement` |
| `settlements()` | Settlement list (new format) 交割列表（新格式） | `POST /api/v1/portfolio/settlements` |
| `trading_limits()` | Trading limits 交易額度 | `POST /api/v1/portfolio/trading_limits` |

---

## Account Balance 帳戶餘額

### Python Usage Python 用法

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Query balance (default: stock_account) 查詢餘額（預設：股票帳戶）
balance = api.account_balance()

# With specific account 指定帳戶
balance = api.account_balance(account=api.stock_account)

# Async callback 非同步回呼
api.account_balance(timeout=0, cb=lambda bal: print(bal))
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (stock_account) | Account to query 查詢帳戶 |
| `timeout` | `int` | `5000` | Timeout ms; 0 = non-blocking 超時毫秒; 0 = 非阻塞 |
| `cb` | `Callable` | `None` | Callback for timeout=0 mode 回呼函數 |

### Attributes 屬性

```python
balance.acc_balance    # float: Available funds 可用餘額
balance.date           # str: Query date 查詢日期
balance.errmsg         # str: Error message 錯誤訊息
```

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/account_balance \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Margin 保證金查詢

### Python Usage Python 用法

```python
# Default: futopt_account 預設：期貨帳戶
margin = api.margin()
margin = api.margin(account=api.futopt_account)
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (futopt_account) | Futures account 期貨帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### Attributes 屬性

```python
margin.yesterday_balance           # float: Yesterday balance 昨日餘額
margin.today_balance               # float: Today balance 今日餘額
margin.deposit_withdrawal          # float: Deposit/withdrawal 出入金
margin.fee                         # float: Fees 手續費
margin.tax                         # float: Tax 稅金
margin.initial_margin              # float: Initial margin 原始保證金
margin.maintenance_margin          # float: Maintenance margin 維持保證金
margin.margin_call                 # float: Margin call 追繳金額
margin.risk_indicator              # float: Risk indicator 風險指標
margin.royalty_revenue_expenditure # float: Royalty revenue/expenditure 權利金收支
margin.equity                      # float: Equity 權益數
margin.equity_amount               # float: Equity amount 權益總值
margin.option_openbuy_market_value # float: Option open buy market value 選擇權買方市值
margin.option_opensell_market_value # float: Option open sell market value 選擇權賣方市值
margin.option_open_position        # float: Options open position P&L 選擇權未平倉損益
margin.option_settle_profitloss    # float: Options settlement P&L 選擇權結算損益
margin.future_open_position        # float: Futures open position P&L 期貨未平倉損益
margin.today_future_open_position  # float: Today futures open position 今日期貨未平倉
margin.future_settle_profitloss    # float: Futures settlement P&L 期貨結算損益
margin.available_margin            # float: Available margin 可用保證金
margin.plus_margin                 # float: Plus margin 加收保證金
margin.plus_margin_indicator       # float: Plus margin indicator 加收保證金指標
margin.security_collateral_amount  # float: Security collateral 有價擔保品
margin.order_margin_premium        # float: Order margin premium 委託保證金
margin.collateral_amount           # float: Collateral amount 擔保品金額
```

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/margin \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_futopt_account_id"}'
```

---

## Positions 持倉查詢

Supports three position unit types via the `unit` parameter:
透過 `unit` 參數支援三種持倉單位：

- `Unit.Common` (default) - Regular lot positions 整股
- `Unit.OddLot` - Odd lot positions 零股
- `Unit.Intraday` - Intraday odd lot positions 盤中零股

### Python Usage Python 用法

```python
# Default: stock or futures account 預設：股票或期貨帳戶
positions = api.list_positions()

# Stock positions 股票持倉
positions = api.list_positions(account=api.stock_account)

# Futures positions 期貨持倉
positions = api.list_positions(account=api.futopt_account)

# Odd lot positions 零股持倉
from shioaji import Unit
positions = api.list_positions(unit=Unit.OddLot)

for pos in positions:
    print(f"Code: {pos.code}, Qty: {pos.quantity}, P&L: {pos.pnl}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account (stock or futures) 帳戶 |
| `unit` | `Unit` | `Common` | Position unit type 持倉單位 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
# Common positions 整股持倉
curl -X POST http://localhost:8080/api/v1/portfolio/position_unit \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id", "unit": "Common"}'

# Odd lot positions 零股持倉
curl -X POST http://localhost:8080/api/v1/portfolio/position_unit \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id", "unit": "OddLot"}'
```

---

## Position Detail 持倉明細

### Python Usage Python 用法

```python
# Get all position details 取得所有持倉明細
details = api.list_position_detail()

# Get specific position detail by ID 依 ID 取得特定持倉明細
details = api.list_position_detail(detail_id=0)
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account 帳戶 |
| `detail_id` | `int` | `0` | Position detail ID (from list_positions cache) 持倉明細 ID |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

Note: `detail_id` is resolved from the position cache populated by `list_positions()`. Call `list_positions()` first.
注意：`detail_id` 從 `list_positions()` 填充的快取中解析。請先呼叫 `list_positions()`。

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/position_detail \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id", "detail_id": 0}'
```

---

## Profit & Loss 損益查詢

### Python Usage Python 用法

```python
# Query by date range 依日期範圍查詢
pnl_list = api.list_profit_loss(
    begin_date="2024-01-01",
    end_date="2024-01-31",
)

# With unit 指定單位
from shioaji import Unit
pnl_list = api.list_profit_loss(
    begin_date="2024-01-01",
    end_date="2024-01-31",
    unit=Unit.Common,
)

for pnl in pnl_list:
    print(f"Code: {pnl.code}, P&L: {pnl.pnl}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account 帳戶 |
| `begin_date` | `str` | `""` | Start date (YYYY-MM-DD) 開始日期 |
| `end_date` | `str` | `""` | End date (YYYY-MM-DD) 結束日期 |
| `unit` | `Unit` | `Common` | Position unit type 持倉單位 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/profit_loss \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "your_account_id",
    "begin_date": "2024-01-01",
    "end_date": "2024-01-31",
    "unit": "Common"
  }'
```

---

## P&L Detail 損益明細

Requires `list_profit_loss()` to be called first to populate the cache.
需先呼叫 `list_profit_loss()` 以填充快取。

### Python Usage Python 用法

```python
# Get detail for a specific profit/loss entry 取得特定損益明細
details = api.list_profit_loss_detail(detail_id=0)

# With unit 指定單位
details = api.list_profit_loss_detail(detail_id=0, unit=Unit.Common)
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account 帳戶 |
| `detail_id` | `int` | `0` | P&L detail ID (from list_profit_loss cache) 損益明細 ID |
| `unit` | `Unit` | `Common` | Position unit type 持倉單位 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/profit_loss_detail \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "your_account_id",
    "detail_id": 0,
    "unit": "Common"
  }'
```

---

## P&L Summary 損益彙總

### Python Usage Python 用法

```python
summary = api.list_profit_loss_summary(
    begin_date="2024-01-01",
    end_date="2024-12-31",
)

print(f"Summary: {summary.total}")
for item in summary.profitloss_summary:
    print(item)
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account 帳戶 |
| `begin_date` | `str` | `""` | Start date (YYYY-MM-DD) 開始日期 |
| `end_date` | `str` | `""` | End date (YYYY-MM-DD) 結束日期 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/profitloss_sum \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "your_account_id",
    "begin_date": "2024-01-01",
    "end_date": "2024-12-31"
  }'
```

---

## Settlements (Legacy) 交割資訊（舊版）

Returns a single settlement object with T/T+1/T+2 breakdown.
回傳單一交割物件，包含 T/T+1/T+2 明細。

### Python Usage Python 用法

```python
settlement = api.list_settlements()

print(f"T day: {settlement.t_day}, T money: {settlement.t_money}")
print(f"T+1 day: {settlement.t1_day}, T+1 money: {settlement.t1_money}")
print(f"T+2 day: {settlement.t2_day}, T+2 money: {settlement.t2_money}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (stock_account) | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### Attributes 屬性

```python
settlement.t_money     # float: T-day amount T 日金額
settlement.t1_money    # float: T+1 amount T+1 日金額
settlement.t2_money    # float: T+2 amount T+2 日金額
settlement.t_day       # str: T-day date T 日日期
settlement.t1_day      # str: T+1 date T+1 日日期
settlement.t2_day      # str: T+2 date T+2 日日期
```

### HTTP Example HTTP 範例

```bash
# Legacy format (single object) 舊格式（單一物件）
curl -X POST http://localhost:8080/api/v1/portfolio/settlement \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Settlements (New) 交割資訊（新版）

Returns a list of settlement entries.
回傳交割項目列表。

### Python Usage Python 用法

```python
settlements = api.settlements()

for s in settlements:
    print(s)
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (stock_account) | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
# New format (list) 新格式（列表）
curl -X POST http://localhost:8080/api/v1/portfolio/settlements \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Trading Limits 交易額度

Query available trading limits for stock account.
查詢股票帳戶的交易額度。

Note: Available on trading days from 8:30 to 15:00.
注意：交易日 8:30 至 15:00 可查詢。

### Python Usage Python 用法

```python
limits = api.trading_limits()

print(f"Trading Limit: {limits.trading_limit}")
print(f"Trading Used: {limits.trading_used}")
print(f"Trading Available: {limits.trading_available}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (stock_account) | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### Attributes 屬性

```python
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

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/trading_limits \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Simulation Mode Notes 模擬模式注意事項

In simulation (paper trading) mode, the following endpoints return default/empty values instead of making real API calls:
模擬（紙上交易）模式下，以下端點回傳預設/空值，不會發起真實 API 呼叫：

- `account_balance()` - returns zero balance 回傳零餘額
- `margin()` - returns zero margin 回傳零保證金
- `list_settlements()` / `settlements()` - returns empty 回傳空值
- `trading_limits()` - returns zero limits 回傳零額度
- `list_profit_loss_summary()` - returns empty summary 回傳空彙總

The following endpoints **do** switch to paper-trading server endpoints:
以下端點**會**切換到模擬伺服器端點：

- `list_positions()` - uses paper position endpoint 使用模擬持倉端點
- `list_profit_loss()` - uses paper P&L endpoint 使用模擬損益端點

---

## HTTP Endpoint Summary HTTP 端點一覽

All endpoints use `POST` method under `/api/v1/portfolio/`:
所有端點使用 `POST` 方法，路徑為 `/api/v1/portfolio/`：

| Path 路徑 | Description 說明 |
|-----------|------------------|
| `/portfolio/account_balance` | Account balance 帳戶餘額 |
| `/portfolio/margin` | Margin info 保證金資訊 |
| `/portfolio/position_unit` | Positions (with unit) 持倉（含單位） |
| `/portfolio/position_detail` | Position detail 持倉明細 |
| `/portfolio/profit_loss` | Profit/loss 損益 |
| `/portfolio/profit_loss_detail` | P&L detail 損益明細 |
| `/portfolio/profitloss_sum` | P&L summary 損益彙總 |
| `/portfolio/settlement` | Settlement (legacy) 交割（舊版） |
| `/portfolio/settlements` | Settlement list (new) 交割列表（新版） |
| `/portfolio/trading_limits` | Trading limits 交易額度 |

See [HTTP_API.md](HTTP_API.md) for full endpoint details.

---

## Reference 參考資料

- Original shioaji docs 原版文檔: https://sinotrade.github.io/tutor/accounting/
