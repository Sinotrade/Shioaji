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
- [IntlAccount 美股帳戶](#intlaccount-美股帳戶)
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
| `list_dividends()` | Cash dividends, IntlAccounts only 現金股利（限美股國際帳戶 IntlAccount） | `POST /api/v1/portfolio/list_dividends` |

`list_positions`, `list_position_detail`, `list_profit_loss`, `list_profit_loss_detail`, `account_balance` and `settlements` pick the row type from the account: IntlAccounts (US stock) get `Intl*` rows, Taiwan accounts are unchanged. See [IntlAccount](#intlaccount-美股帳戶) (1.8.0b1).
`list_positions`、`list_position_detail`、`list_profit_loss`、`list_profit_loss_detail`、`account_balance`、`settlements` 依帳戶類型決定回傳型別：國際帳戶（IntlAccount，美股）回 `Intl*`，台股不變（1.8.0b1）。

---

## Accounting Response and Decision Summary 帳務回應與決策摘要

Use this table before generating accounting code. Python returns wrapper objects/lists; HTTP clients receive server JSON; CLI exposes portfolio commands (`balance`, `positions`, `margin`, `position-detail`, `profit-loss`, `profit-loss-detail`, `profit-loss-summary`, `trading-limits`, `settlements`, `dividends`) and uses TOON output by default unless `--format json` is requested.
產生帳務查詢程式前先看這張表。Python 回傳 wrapper object/list；HTTP client 收到 server JSON；CLI 提供 portfolio 指令（`balance`、`positions`、`margin`、`position-detail`、`profit-loss`、`profit-loss-detail`、`profit-loss-summary`、`trading-limits`、`settlements`、`dividends`），預設為 TOON 輸出，除非指定 `--format json`。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| Account balance | `api.account_balance(...)` -> `AccountBalance`, or `IntlAccountBalance` for an IntlAccount (`currency=` IntlAccount only, default USD) | `POST /api/v1/portfolio/account_balance` -> `AccountBalance { acc_balance, date, errmsg }`, or `IntlAccountBalance { account_type, currency, balance, buying_power }` for an IntlAccount | `shioaji portfolio balance` (`--account-type H [--currency USD]` for an IntlAccount); JSON follows HTTP shape | Default account is stock. Taiwan accounts ignore `currency`. Check `errmsg` before trusting `acc_balance`; in simulation, Taiwan accounts get a zero/default balance that must not be treated as real buying power; IntlAccounts query the paper account. |
| Futures margin | `api.margin(...)` -> `Margin` | `POST /api/v1/portfolio/margin` -> `Margin` | `shioaji portfolio margin`; JSON follows HTTP shape | Requires futures/options account. If the caller supplies a stock account, fix account selection before interpreting fields. Simulation can return default zero margin. IntlAccounts are not supported: the SDK fails locally with `UnsupportedAccountOperation` (Python `ShioajiValueError`, HTTP 400) before sending any request. 國際帳戶（IntlAccount）不支援，會本地報錯。 |
| Positions | `api.list_positions(...)` -> `List[StockPosition | FuturePosition]`; IntlAccount -> `List[IntlPosition]` | `POST /api/v1/portfolio/position_unit` -> `Vec<Position>` (IntlAccount rows carry `account_type: "H"`) | `shioaji portfolio positions`; `--account-type H` for US stock; JSON follows HTTP shape | Empty list can be normal. Before calling it failure, verify account type (`S`/`F`/`H`) and `unit` (`Common` vs `Share`; ignored for H). |
| Position detail | `api.list_position_detail(detail_id=...)` -> `List[StockPositionDetail | FuturePositionDetail]`; IntlAccount -> `List[IntlPositionDetail]` (tax lots) | `POST /api/v1/portfolio/position_detail` -> `Vec<PositionDetail>` | `shioaji portfolio position-detail --detail-id <ID>`; JSON follows HTTP shape | Taiwan stock odd lots need `unit=Share` (default `Common` counts lots). Call `list_positions()` first in Python or query positions first over HTTP/CLI, then use the intended position `id` as `detail_id` (same for an IntlAccount). Empty detail usually means wrong/stale `detail_id` or account. |
| Realized P&L | `api.list_profit_loss(...)` -> `List[StockProfitLoss | FutureProfitLoss]`; IntlAccount -> `List[IntlProfitLoss]` (sells only) | `POST /api/v1/portfolio/profit_loss` -> `Vec<ProfitLoss>` | `shioaji portfolio profit-loss`; dates default to today; JSON follows HTTP shape | Empty list can mean no realized P&L in the date range. Check date range, account type, and `unit` before changing logic. H dividends are not P&L rows: use `list_dividends`. |
| P&L detail | `api.list_profit_loss_detail(detail_id=...)` -> `List[StockProfitDetail | FutureProfitDetail]`; IntlAccount -> `List[IntlProfitLossDetail]` | `POST /api/v1/portfolio/profit_loss_detail` -> `Vec<ProfitDetail>` | `shioaji portfolio profit-loss-detail --detail-id <ID>`; JSON follows HTTP shape | Call `list_profit_loss()` first and pass the selected P&L row id. For stock detail, `quantity` is an integer. IntlAccounts pass the row's `detail_id` **string** unchanged (an int fails locally); a tampered or foreign id returns HTTP 400 `INVALID_DETAIL_ID`. |
| Dividends (IntlAccount only) | `api.list_dividends(...)` -> `List[IntlDividend]` | `POST /api/v1/portfolio/list_dividends` -> `Vec<IntlDividend>` | `shioaji portfolio dividends`; dates default to today | Cash dividends only, by pay date. A Taiwan account fails locally with `UnsupportedAccountOperation`. Stock dividends appear as `NonTrade` lots in `list_position_detail`. |
| P&L summary | `api.list_profit_loss_summary(...)` -> `ProfitLossSummaryTotal` | `POST /api/v1/portfolio/profitloss_sum` -> `ProfitLossSummaryTotal` | `shioaji portfolio profit-loss-summary`; dates default to today; JSON follows HTTP shape | Use this for summarized realized P&L. In simulation it can return an empty summary/default total. |
| Settlement legacy | `api.list_settlements(...)` -> `SettlementLegacy` | `POST /api/v1/portfolio/settlement` -> `SettlementLegacy` | No CLI command (legacy, intentionally not exposed) | Returns a single T/T+1/T+2 object. Prefer the settlement list below. IntlAccounts are not supported: the SDK fails locally with `UnsupportedAccountOperation` before sending any request; use `settlements()` instead. 國際帳戶（IntlAccount）不支援，會本地報錯。 |
| Settlement list | `api.settlements(...)` -> `List[SettlementV1]` (Taiwan) or `List[IntlSettlement]` (IntlAccount); Python dates are `datetime.date` | `POST /api/v1/portfolio/settlements` -> `Settlement[]` (Taiwan) or `IntlSettlement[]` (IntlAccount) JSON | `shioaji portfolio settlements` (`--account-type H` for an IntlAccount); JSON follows HTTP shape | Taiwan: date/amount/T rows. H: unsettled rows only (trade_date/settlement_date/net_amount/currency). Do not copy Python `datetime.date` assumptions into HTTP clients. Simulation returns empty for Taiwan accounts; IntlAccounts query the paper account. |
| Trading limits | `api.trading_limits(...)` -> `TradingLimits` | `POST /api/v1/portfolio/trading_limits` -> `TradingLimits` | `shioaji portfolio trading-limits`; JSON follows HTTP shape | Stock account only. Available on trading days 08:30-15:00; default/zero values in simulation are not production affordability. IntlAccounts are not supported: the SDK fails locally with `UnsupportedAccountOperation` before sending any request. 國際帳戶（IntlAccount）不支援，會本地報錯。 |

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

# IntlAccount: IntlAccountBalance, currency defaults to USD
# 國際帳戶（IntlAccount）：回傳 IntlAccountBalance，currency 預設 USD
intl_balance = api.account_balance(account=intl_acct, currency="USD")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` (stock_account) | Account to query 查詢帳戶 |
| `currency` | `Currency` / `str` | `None` (IntlAccount: USD) | IntlAccounts only: currency of the balance; ignored for Taiwan accounts. An unsupported currency returns 400 `INVALID_CURRENCY` from the backend. 僅國際帳戶（IntlAccount）使用，台股帳戶忽略 |
| `timeout` | `int` | `30000` | Timeout ms; 0 = non-blocking 超時毫秒; 0 = 非阻塞 |
| `cb` | `Callable` | `None` | Callback for timeout=0 mode 回呼函數 |

### Attributes 屬性

```python
balance.acc_balance    # float: Available funds 可用餘額
balance.date           # str: Query date 查詢日期
balance.errmsg         # str: Error message 錯誤訊息

# IntlAccountBalance (IntlAccount 國際帳戶)
balance.account_type   # "H"
balance.currency       # Currency: currency of balance and buying_power
balance.balance        # Decimal: account cash balance, not affected by orders (upstream TSHK3052 BuyingPower)
                       # 帳戶現金餘額，不受委託影響
balance.buying_power   # Decimal: cash available to place orders: deducted as soon as a buy order is placed,
                       # restored when cancelled, excludes margin financing (upstream Amount)
                       # 可下單金額：買單送出即扣、刪單回補，不含融資
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

# Odd-lot quantities in shares 零股以股數顯示
from shioaji import Unit
details = api.list_position_detail(detail_id=0, unit=Unit.Share)
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | `None` | Account 帳戶 |
| `detail_id` | `int` | `0` | Position detail ID (from list_positions cache) 持倉明細 ID |
| `timeout` | `int` | `30000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |
| `unit` | `Unit` | `Common` | Taiwan stock only; `Share` returns quantities in shares (odd lots), ignored for futures and IntlAccounts 僅台股；`Share` 以股數回傳（零股），期貨與國際帳戶忽略 |

Note: `detail_id` is resolved from the position cache populated by `list_positions()`. Call `list_positions()` first.
注意：`detail_id` 從 `list_positions()` 填充的快取中解析。請先呼叫 `list_positions()`。

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/position_detail \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id", "detail_id": 0, "unit": "Share"}'
```

`unit` defaults to `"Common"`; Taiwan stock only. `unit` 預設 `"Common"`，僅台股。

### CLI Example CLI 範例

```bash
shioaji portfolio position-detail --detail-id 0
shioaji portfolio position-detail --detail-id 0 --unit share
shioaji portfolio position-detail --detail-id 0 --account-type F
shioaji portfolio position-detail --detail-id 0 --account 9A00-1234567 --format json
```

---

## Profit & Loss 損益查詢

`StockProfitLoss.pnl_pct` is the return rate in percent (`5.55` means 5.55%).
`pr_ratio` is kept unchanged for compatibility and is a fraction here (`0.0555`),
so `pnl_pct = pr_ratio * 100`. HTTP and CLI JSON responses include both fields.
`StockProfitLoss.pnl_pct` 是報酬率，單位為 %（`5.55` 代表 5.55%）；
`pr_ratio` 保留原值以維持相容，在這支 API 是小數（`0.0555`），所以
`pnl_pct = pr_ratio * 100`。HTTP 與 CLI JSON 回應包含兩個欄位。

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

`StockProfitLossSummary` and `ProfitLossTotal` also expose `pnl_pct` as the new
return rate in percent (`5.55` means 5.55%), with `pr_ratio` retained for
compatibility. The summary `pr_ratio` is already a percent, so both fields have
the same value here (unlike `StockProfitLoss`, whose `pr_ratio` is a fraction).
`StockProfitLossSummary` 與 `ProfitLossTotal` 同樣以 `pnl_pct` 為報酬率的新名稱
（單位 %，`5.55` 代表 5.55%），並保留 `pr_ratio` 以維持相容。彙總的
`pr_ratio` 本來就是百分比，所以兩個欄位數值相同（`StockProfitLoss` 的
`pr_ratio` 則是小數）。

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

IntlAccounts return `IntlSettlement` rows instead; see [IntlAccount](#intlaccount-美股帳戶).
IntlAccount 回傳 `IntlSettlement`，見下方國際帳戶（IntlAccount）一節。

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
shioaji portfolio settlements --account-type H --format json   # IntlSettlement rows
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

## IntlAccount 美股帳戶

Since 1.8.0b1 (pre-release: `pip install --pre shioaji` or `shioaji==1.8.0b2`). IntlAccounts (US stocks, 複委託) reuse the same portfolio functions, but the SDK picks a dedicated return type from the account's `account_type`. Every IntlAccount row carries `account_type == "H"`; all prices, quantities and amounts are `Decimal` (fractional shares allowed), and missing values are `None` instead of `0`.
1.8.0b1（預發行版）起支援。國際帳戶（IntlAccount，美股複委託）沿用同一組帳務函式，SDK 依帳號的 `account_type` 決定回傳型別。每列都帶 `account_type == "H"`；價格、數量、金額一律 `Decimal`（可為零股小數），缺值為 `None`，不補 0。

| Function 函式 | Taiwan return 台股回傳 | IntlAccount return IntlAccount 回傳 |
|---------------|------------------------|---------------------|
| `list_positions` | `StockPosition` / `FuturePosition` | `IntlPosition` |
| `list_position_detail` | `StockPositionDetail` / `FuturePositionDetail` | `IntlPositionDetail` (tax lots 稅批) |
| `list_profit_loss` | `StockProfitLoss` / `FutureProfitLoss` | `IntlProfitLoss` (sells only 僅賣出) |
| `list_profit_loss_detail` | `StockProfitDetail` / `FutureProfitDetail` | `IntlProfitLossDetail` |
| `list_dividends` | not supported (local error) 不支援，本地報錯 | `IntlDividend` |
| `account_balance` | `AccountBalance` | `IntlAccountBalance` (`currency=`, default USD 預設 USD) |
| `settlements` | `SettlementV1` | `IntlSettlement` (unsettled only 僅未交割) |
| `list_settlements` | `Settlement` (legacy 舊版) | not supported (local error; use `settlements()`) 不支援，本地報錯，請改用 `settlements()` |
| `margin`, `trading_limits` | `Margin` / `TradingLimits` | not supported (local error) 不支援，本地報錯 |

`margin`, `trading_limits` and `list_settlements` raise `sj.ShioajiValueError` for an IntlAccount before any request (HTTP 400); the message contains `UnsupportedAccountOperation: margin is not supported for IntlAccounts.` (the API name changes; `list_settlements` adds `use settlements() instead`). `list_dividends` with a Taiwan account raises `UnsupportedAccountOperation: list_dividends is only supported for IntlAccounts.`
`margin`、`trading_limits`、`list_settlements` 對國際帳戶（IntlAccount）本地丟 `ShioajiValueError`（HTTP 400），不送出請求；`list_dividends` 用台股帳戶也會本地報錯。

### Input Rules 輸入規則

- `region` keeps its Taiwan default; for an IntlAccount a missing `region` or `TW` means `US`. 國際帳戶（IntlAccount）未給 `region` 或給 `TW` 都視為 `US`。
- `currency` is optional and defaults to the region's currency (`US` -> `USD`). `currency` 選填，預設為該市場幣別。
- `unit` is ignored for IntlAccounts (no error). 國際帳戶（IntlAccount）忽略 `unit`，不報錯。
- `list_profit_loss_detail(account, detail_id)`: for an IntlAccount pass the row's `detail_id` **string** exactly as returned by `list_profit_loss`. It is opaque: do not parse or build it. Passing an int fails locally; a tampered, expired or foreign id returns HTTP 400 `INVALID_DETAIL_ID`, passed through unchanged. Taiwan accounts keep the int row id.
  國際帳戶（IntlAccount）的 `detail_id` 是 `list_profit_loss` 回傳的不透明字串，原樣傳回；傳 int 會本地報錯，竄改或他人的 id 由後端回 400 `INVALID_DETAIL_ID`。台股帳戶仍用 int。
- `list_position_detail(detail_id=...)` uses the `IntlPosition.id` assigned by the SDK (0..n in list order), same as Taiwan. 同台股，用 `list_positions()` 回傳的 `id`。
- `list_dividends` fails locally with `UnsupportedAccountOperation` for non-Intl accounts. Without `account` it uses the first IntlAccount. 非國際帳戶本地報錯；未給 `account` 時用第一個國際帳戶（IntlAccount）。
- `list_settlements` fails locally with `UnsupportedAccountOperation` for IntlAccounts; use `settlements()`. 國際帳戶（IntlAccount）呼叫 `list_settlements` 本地報錯，請改用 `settlements()`。
- `settlements` for an IntlAccount returns only rows not yet settled (`settlement_date` is today or later): one row per trade date and side, fees included. Today's trades appear from the next day. Only foreign-currency settlement is covered for now. 國際帳戶（IntlAccount）的 `settlements` 只回未交割的資料（交割日為今天或之後），每個成交日、買賣方向一列，已含費用；當日成交隔天才出現；目前只支援外幣交割。
- `list_positions()` / `list_profit_loss()` without `account` use the default stock (or futures) account, not the IntlAccount: always pass the IntlAccount for US rows. 不給 `account` 時用台股預設帳戶，查美股要明確傳國際帳戶（IntlAccount）。
- `pnl_pct` is always a percentage (`12.3` means 12.3%), for IntlAccount rows and Taiwan `StockProfitLoss` alike; do not multiply by 100. `pnl_pct` 一律為百分比數值（12.3 表示 12.3%），不要再乘 100。
- `market_price` of `IntlPosition` / `IntlPositionDetail` is a backend reference price, not a live quote; for a live price use US quotes ([STREAMING.md § US Quotes](STREAMING.md#us-quotes-美股行情)). `market_price` 是後台參考價，不是即時報價。

### Python Example Python 範例

```python
intl_acct = next(a for a in api.list_accounts() if a.account_type == sj.AccountType.Intl)

positions = api.list_positions(intl_acct)                      # List[IntlPosition]
lots = api.list_position_detail(intl_acct, detail_id=positions[0].id)

pnl = api.list_profit_loss(intl_acct, begin_date="2026-01-01", end_date="2026-03-31")
detail = api.list_profit_loss_detail(intl_acct, detail_id=pnl[0].detail_id)  # str

divs = api.list_dividends(intl_acct, begin_date="2026-01-01", end_date="2026-03-31")
for d in divs:
    print(d.code, d.pay_date, d.net_amount, d.currency)

for s in api.settlements(intl_acct):                           # List[IntlSettlement]
    print(s.trade_date, s.settlement_date, s.net_amount, s.currency)
```

### Attributes 屬性

```python
# IntlPosition
p.id, p.account_type, p.code, p.direction          # direction is always Action.Buy
p.quantity, p.price, p.cost_basis                  # Decimal
p.market_price                                     # Optional[Decimal]: reference price 參考價, not a live quote
p.market_value, p.pnl, p.pnl_pct                   # Optional[Decimal]
p.currency, p.base_currency                        # Currency

# IntlPositionDetail (one row per tax lot)
d.code, d.quantity, d.original_quantity            # Decimal
d.acquired_date                                    # datetime.date
d.acquisition_type                                 # AcquisitionType.Buy / AcquisitionType.NonTrade (e.g. stock dividend 配股)
d.price, d.cost                                    # Decimal
d.market_price, d.pnl                              # Optional[Decimal]
d.settlement_currency, d.currency, d.base_currency # Currency

# IntlProfitLoss
r.detail_id                                        # str, opaque
r.code, r.direction, r.date                        # Action, datetime.date
r.quantity, r.price, r.cost                        # Decimal
r.pnl, r.pnl_pct                                   # Decimal; pnl_pct in percent (20.78 = 20.78%)
r.currency, r.base_currency

# IntlProfitLossDetail (lots consumed by one sell)
x.acquired_date                                    # Optional[datetime.date]: None when the backend has no date
x.quantity, x.price, x.cost                        # Decimal
x.fee, x.tax, x.other_fees                         # Decimal
x.currency, x.base_currency

# IntlDividend (cash dividends, by pay date)
v.code, v.pay_date, v.record_date
v.quantity, v.gross_amount, v.net_amount          # Decimal
v.withholding_tax                                  # Decimal: source-country withholding tax 來源國扣繳稅
                                                   # (US stocks: US withholding; ADR: issuer country's)
v.currency, v.base_currency, v.settlement_currency

# IntlSettlement (unsettled settlements only 僅未交割)
s.account_type                                     # "H"
s.trade_date, s.settlement_date                    # datetime.date
s.net_amount                                       # Decimal, fees included: + cash in 收, - cash out 付
s.currency                                         # Currency
```

Every class supports `repr()` in `ClassName(field=..., ...)` form and the mapping protocol (`dict(row)`, `row["code"]`).
每個類別都有 `ClassName(field=..., ...)` 格式的 `repr()` 與 mapping protocol。

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/portfolio/position_unit \
  -H "Content-Type: application/json" \
  -d '{"account_type": "H", "region": "US"}'

curl -X POST http://localhost:8080/api/v1/portfolio/profit_loss_detail \
  -H "Content-Type: application/json" \
  -d '{"account_type": "H", "detail_id": "<detail_id from profit_loss>"}'

curl -X POST http://localhost:8080/api/v1/portfolio/list_dividends \
  -H "Content-Type: application/json" \
  -d '{"account_type": "H", "begin_date": "2026-01-01", "end_date": "2026-03-31"}'

curl -X POST http://localhost:8080/api/v1/portfolio/settlements \
  -H "Content-Type: application/json" \
  -d '{"account_type": "H"}'
# [{"account_type": "H", "trade_date": "2026-11-17", "settlement_date": "2026-11-18",
#   "net_amount": "-9554.64", "currency": "USD"}]
```

HTTP responses are JSON; `Decimal` fields are strings (e.g. `"10.5"`) and dates are `YYYY-MM-DD`. `/portfolio/list_dividends` defaults `account_type` to `H`.
HTTP 回應中 `Decimal` 欄位為字串，日期為 `YYYY-MM-DD`；`/portfolio/list_dividends` 的 `account_type` 預設為 `H`。

For IntlAccounts a missing `region` or `region="TW"` is sent as `US`; `currency` defaults to the region currency (USD). Backend 400 errors keep the server detail, e.g. `GTRADE error: INVALID_DETAIL_ID: invalid detail_id`, `UNSUPPORTED_DIVIDEND_CURRENCY`, `INVALID_CODE`, `INVALID_REGION`.
國際帳戶（IntlAccount）未帶 `region` 或 `region="TW"` 一律以 `US` 送出；`currency` 預設為該市場幣別（USD）。後端 400 錯誤保留伺服器原文，例如 `GTRADE error: INVALID_DETAIL_ID: invalid detail_id`、`UNSUPPORTED_DIVIDEND_CURRENCY`、`INVALID_CODE`、`INVALID_REGION`。

### CLI Example CLI 範例

```bash
shioaji portfolio positions --account-type H
shioaji portfolio position-detail --account-type H --detail-id 0
shioaji portfolio profit-loss --account-type H --begin-date 2026-01-01 --end-date 2026-03-31
shioaji portfolio profit-loss-detail --account-type H --detail-id '<detail_id>'
shioaji portfolio dividends --begin-date 2026-01-01 --end-date 2026-03-31 --format json
```

`--region` and `--currency` are accepted on `positions`, `position-detail`, `profit-loss` and `dividends`.

---

## Simulation Mode Notes 模擬模式注意事項

In simulation (paper trading) mode, the following endpoints return default/empty values instead of making real API calls:
模擬（紙上交易）模式下，以下端點回傳預設/空值，不會發起真實 API 呼叫：

- `account_balance()` - returns zero balance for Taiwan accounts 台股帳戶回傳零餘額
- `margin()` - returns zero margin 回傳零保證金
- `list_settlements()` / `settlements()` - returns empty for Taiwan accounts 台股帳戶回傳空值
- `trading_limits()` - returns zero limits 回傳零額度
- `list_profit_loss_summary()` - returns empty summary 回傳空彙總
- `list_position_detail()` - returns empty for Taiwan accounts 台股帳戶回傳空值
- `list_profit_loss_detail()` - returns empty for Taiwan accounts 台股帳戶回傳空值
- `list_dividends()` - returns empty 回傳空值（國際帳戶 IntlAccount 亦同）

The following endpoints **do** switch to paper-trading server endpoints:
以下端點**會**切換到模擬伺服器端點：

- `list_positions()` - uses paper position endpoint 使用模擬持倉端點
- `list_profit_loss()` - uses paper P&L endpoint 使用模擬損益端點
- `account_balance()` / `settlements()` / `list_position_detail()` / `list_profit_loss_detail()` for IntlAccounts - use `api/v1/paper/account_balance` / `api/v1/paper/settlements` / `api/v1/paper/position_detail` / `api/v1/paper/profit_loss_detail` (detail_id `paper.YYYYMMDD.ORDER` from `list_profit_loss`), same request and reply shapes as live 國際帳戶（IntlAccount）使用模擬端點，格式同正式。Paper tax lots: fills of the same buy order on the same trade date form one lot, oldest first (FIFO); `cost` includes the buy fee and the lots add up to `cost_basis` of `list_positions`; after a partial sell `quantity` is what is left and `original_quantity` the bought quantity. 模擬庫存明細依 FIFO，同一張買單同一交易日合成一批，cost 含買進手續費。
  - In simulation, the IntlAccount `buying_power` already deducts the hold of open buy orders. When paper cannot compute it (for example an open market buy order with no reference price), the paper `account_balance` returns HTTP 503 and the SDK raises a `SystemMaintenance` error; retry later. 模擬國際帳戶（IntlAccount） buying_power 已扣買單圈存；paper 算不出（例如市價買單沒有參考價）會回 503，SDK 拋 SystemMaintenance 錯誤，稍後再查。

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
| `/portfolio/list_dividends` | Cash dividends, IntlAccounts only 現金股利（僅國際帳戶 IntlAccount） |

See [HTTP_API.md](HTTP_API.md) for full endpoint details.
