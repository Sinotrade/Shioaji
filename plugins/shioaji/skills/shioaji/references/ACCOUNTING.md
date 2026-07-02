# Accounting 帳務查詢

This document covers account balance, margin, positions, profit/loss, settlements, and trading limits in Shioaji.
本文件說明 Shioaji 中的帳戶餘額、保證金、持倉、損益、交割及交易額度查詢。

See [HTTP_API.md](HTTP_API.md) for endpoint details. This file owns accounting response types and agent branching decisions.

Attribute blocks in this file describe Python wrapper objects. HTTP and CLI clients receive server JSON response shapes, so use the endpoint-specific notes in this file and fetch `/openapi.json` only when exact installed-server field typing is required.
本檔的屬性區塊描述 Python wrapper 物件。HTTP 與 CLI client 收到的是 server JSON response shape；agent 要決策前，請依本檔各端點說明判斷；只有需要確認安裝版本精確欄位型別時才查 `/openapi.json`。

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Accounting Response and Decision Summary 帳務回應與決策摘要](#accounting-response-and-decision-summary-帳務回應與決策摘要)
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

## Accounting Response and Decision Summary 帳務回應與決策摘要

Use this table before generating accounting code. Python returns wrapper objects/lists; HTTP clients receive server JSON; CLI exposes portfolio commands (`balance`, `positions`, `margin`, `position-detail`, `profit-loss`, `profit-loss-detail`, `profit-loss-summary`, `trading-limits`, `settlements`) and uses TOON output by default unless `--format json` is requested.
產生帳務查詢程式前先看這張表。Python 回傳 wrapper object/list；HTTP client 收到 server JSON；CLI 提供 portfolio 指令（`balance`、`positions`、`margin`、`position-detail`、`profit-loss`、`profit-loss-detail`、`profit-loss-summary`、`trading-limits`、`settlements`），預設為 TOON 輸出，除非指定 `--format json`。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| Account balance | `api.account_balance(...)` -> `AccountBalance` | `POST /api/v1/portfolio/account_balance` -> `AccountBalance { acc_balance, date, errmsg }` | `shioaji portfolio balance`; JSON follows HTTP shape | Default account is stock. Check `errmsg` before trusting `acc_balance`; in simulation, zero/default balance is expected and must not be treated as real buying power. |
| Futures margin | `api.margin(...)` -> `Margin` | `POST /api/v1/portfolio/margin` -> `Margin` | `shioaji portfolio margin`; JSON follows HTTP shape | Requires futures/options account. If the caller supplies a stock account, fix account selection before interpreting fields. Simulation can return default zero margin. |
| Positions | `api.list_positions(...)` -> `List[StockPosition | FuturePosition]` | `POST /api/v1/portfolio/position_unit` -> `Vec<Position>` | `shioaji portfolio positions`; JSON follows HTTP shape | Empty list can be normal. Before calling it failure, verify account type (`S`/`F`) and `unit` (`Common` vs `Share`). |
| Position detail | `api.list_position_detail(detail_id=...)` -> `List[StockPositionDetail | FuturePositionDetail]` | `POST /api/v1/portfolio/position_detail` -> `Vec<PositionDetail>` | `shioaji portfolio position-detail --detail-id <ID>`; JSON follows HTTP shape | Call `list_positions()` first in Python or query positions first over HTTP/CLI, then use the intended position `id` as `detail_id`. Empty detail usually means wrong/stale `detail_id` or account. |
| Realized P&L | `api.list_profit_loss(...)` -> `List[StockProfitLoss | FutureProfitLoss]` | `POST /api/v1/portfolio/profit_loss` -> `Vec<ProfitLoss>` | `shioaji portfolio profit-loss`; dates default to today; JSON follows HTTP shape | Empty list can mean no realized P&L in the date range. Check date range, account type, and `unit` before changing logic. |
| P&L detail | `api.list_profit_loss_detail(detail_id=...)` -> `List[StockProfitDetail | FutureProfitDetail]` | `POST /api/v1/portfolio/profit_loss_detail` -> `Vec<ProfitDetail>` | `shioaji portfolio profit-loss-detail --detail-id <ID>`; JSON follows HTTP shape | Call `list_profit_loss()` first and pass the selected P&L row id. For stock detail, `quantity` is an integer. |
| P&L summary | `api.list_profit_loss_summary(...)` -> `ProfitLossSummaryTotal` | `POST /api/v1/portfolio/profitloss_sum` -> `ProfitLossSummaryTotal` | `shioaji portfolio profit-loss-summary`; dates default to today; JSON follows HTTP shape | Use this for summarized realized P&L. In simulation it can return an empty summary/default total. |
| Settlement legacy | `api.list_settlements(...)` -> `SettlementLegacy` | `POST /api/v1/portfolio/settlement` -> `SettlementLegacy` | No CLI command (legacy, intentionally not exposed) | Returns a single T/T+1/T+2 object. Prefer the settlement list below. |
| Settlement list | `api.settlements(...)` -> `List[Settlement]`; Python `date` is `datetime.date` | `POST /api/v1/portfolio/settlements` -> `Vec<Settlement>` JSON | `shioaji portfolio settlements`; JSON follows HTTP shape | Current settlement-list shape (date/amount/T rows). Do not copy Python `datetime.date` assumptions into HTTP clients. Simulation can return empty. |
| Trading limits | `api.trading_limits(...)` -> `TradingLimits` | `POST /api/v1/portfolio/trading_limits` -> `TradingLimits` | `shioaji portfolio trading-limits`; JSON follows HTTP shape | Stock account only. Available on trading days 08:30-15:00; default/zero values in simulation are not production affordability. |

All HTTP portfolio requests accept account selectors such as `account_type`, `broker_id`, and `account_id`. If an empty list or default object is surprising, check `/api/v1/info` for `simulation`, then check account selection before guessing the business meaning.
所有 HTTP portfolio request 可帶 `account_type`、`broker_id`、`account_id` 等帳號 selector。若空陣列或預設物件看起來不合理，先用 `/api/v1/info` 確認 `simulation`，再檢查帳號選擇，不要直接猜業務含義。

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
| `timeout` | `int` | `30000` | Timeout ms; 0 = non-blocking 超時毫秒; 0 = 非阻塞 |
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
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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

Supports two position unit types via the `unit` parameter:
透過 `unit` 參數支援兩種持倉單位：

- `Unit.Common` (default) - Regular lot positions 整股
- `Unit.Share` - Share-level / odd-lot positions 股數單位／零股

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
positions = api.list_positions(unit=Unit.Share)

for pos in positions:
    print(f"Code: {pos.code}, Qty: {pos.quantity}, P&L: {pos.pnl}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account (stock or futures) 帳戶 |
| `unit` | `Unit` | `Common` | Position unit type 持倉單位 |
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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
  -d '{"account_id": "your_account_id", "unit": "Share"}'
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
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

Note: `detail_id` is resolved from the position cache populated by `list_positions()`. Call `list_positions()` first.
注意：`detail_id` 從 `list_positions()` 填充的快取中解析。請先呼叫 `list_positions()`。

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/position_detail \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id", "detail_id": 0}'
```

### CLI Example CLI 範例

```bash
shioaji portfolio position-detail --detail-id 0
shioaji portfolio position-detail --detail-id 0 --account-type F
shioaji portfolio position-detail --detail-id 0 --account 9A00-1234567 --format json
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
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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

### CLI Example CLI 範例

```bash
shioaji portfolio profit-loss                                # today, stock account 今日、股票帳戶
shioaji portfolio profit-loss --begin-date 2024-01-01 --end-date 2024-01-31
shioaji portfolio profit-loss --account-type F               # futures account 期貨帳戶
shioaji portfolio profit-loss --unit share --format json
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

For stock P&L details, `detail.quantity` is an `int`.
股票損益明細中的 `detail.quantity` 是 `int`。

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account 帳戶 |
| `detail_id` | `int` | `0` | P&L detail ID (from list_profit_loss cache) 損益明細 ID |
| `unit` | `Unit` | `Common` | Position unit type 持倉單位 |
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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

### CLI Example CLI 範例

```bash
shioaji portfolio profit-loss-detail --detail-id 0
shioaji portfolio profit-loss-detail --detail-id 0 --unit share
shioaji portfolio profit-loss-detail --detail-id 0 --account-type F --format json
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
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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

### CLI Example CLI 範例

```bash
shioaji portfolio profit-loss-summary                        # today, stock account 今日、股票帳戶
shioaji portfolio profit-loss-summary --begin-date 2024-01-01 --end-date 2024-12-31
shioaji portfolio profit-loss-summary --account-type F --format json
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
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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

No CLI command for the legacy format — use `shioaji portfolio settlements` (new list format below).
舊格式無 CLI 指令——請使用 `shioaji portfolio settlements`（下方新版列表格式）。

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

### Attributes 屬性

```python
s.date    # datetime.date: Settlement date 交割日
s.amount  # float: Settlement amount 交割金額
s.T       # int: T offset T 日偏移
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (stock_account) | Stock account 股票帳戶 |
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
# New format (list) 新格式（列表）
curl -X POST http://localhost:8080/api/v1/portfolio/settlements \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

### CLI Example CLI 範例

The CLI `settlements` command uses this endpoint and returns the settlement list (date/amount/T rows).
CLI 的 `settlements` 指令使用此端點，回傳交割列表（date/amount/T 列）。

```bash
shioaji portfolio settlements
shioaji portfolio settlements --account 9A00-1234567 --format json
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
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
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

### CLI Example CLI 範例

```bash
shioaji portfolio trading-limits
shioaji portfolio trading-limits --account 9A00-1234567 --format json
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
