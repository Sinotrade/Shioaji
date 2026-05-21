# Preparation 準備工作

This document covers installation, environment configuration, authentication, and common setup for the RShioaji (Rust-based Shioaji) trading API.
本文件說明 RShioaji（Rust 版 Shioaji）的安裝、環境設定、認證和常用設定。

## Table of Contents 目錄

- [Installation 安裝](#installation-安裝)
- [Environment Variables 環境變數](#environment-variables-環境變數)
- [Login 登入](#login-登入)
- [Python Sync vs Async 同步與異步](#python-sync-vs-async-同步與異步)
- [Account Setup 帳戶設定](#account-setup-帳戶設定)
- [Common Constants 常用常數](#common-constants-常用常數)
- [Simulation vs Production Mode 模擬與正式模式](#simulation-vs-production-mode-模擬與正式模式)
- [CA Certificate Activation 憑證啟用](#ca-certificate-activation-憑證啟用)

---

## Installation 安裝

RShioaji can be installed as a Python package or as a standalone CLI binary.
RShioaji 可作為 Python 套件或獨立 CLI 二進制檔安裝。

### Python Package 套件安裝

```bash
# uv (recommended 推薦)
uv add rshioaji

# pip (alternative)
pip install rshioaji
```

### CLI Tool Install CLI 工具安裝

```bash
# uv tool (recommended 推薦) — persistent install, puts `shioaji` on PATH
uv tool install rshioaji
shioaji server

# uvx — one-shot, no persistent install 一次性執行
uvx --from rshioaji shioaji server
# NOTE: when rshioaji ships as production `shioaji` package, this becomes:
# uvx shioaji server
```

### Standalone Binary 獨立二進制檔

**Linux / macOS:**

```bash
# Stable
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh

# Pre-release
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | CHANNEL=prerelease sh

# Specific version
curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | VERSION=v1.5.0 sh
```

**Windows (PowerShell):**

```powershell
# Stable
irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex

# Pre-release
$env:CHANNEL="prerelease"; irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex

# Specific version
$env:VERSION="v1.5.0"; irm https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.ps1 | iex
```

> **Note**: installer URLs will change from `sinotrade/rshioaji` to `sinotrade/shioaji` when the production version ships.

### Verify Installation 驗證安裝

```python
import shioaji as sj

api = sj.Shioaji()
print(f"Shioaji version: {sj.__version__}")
```

---

## Environment Variables 環境變數

All environment variables recognized by RShioaji. These can be set in a `.env` file (auto-loaded by CLI) or exported in the shell.
RShioaji 支援的所有環境變數。可以在 `.env` 檔案（CLI 自動載入）或 shell 中設定。

### Authentication 認證

| Variable 變數 | Required 必填 | Description 說明 |
|---|---|---|
| `SJ_API_KEY` | Yes (CLI/server) | API key for Shioaji authentication. Required for CLI and server mode. Python can pass directly to `login()`. |
| `SJ_SEC_KEY` | Yes (CLI/server) | Secret key for Shioaji authentication. Required for CLI and server mode. Python can pass directly to `login()`. |

### Client 客戶端

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `SJ_PROXY` | (none) | HTTP proxy URL for all API requests |
| `SJ_CA_PATH` | (none) | Path to CA certificate file (.pfx) for order signing |
| `SJ_CA_PASSWD` | (none) | CA certificate password |
| `SJ_HOME_PATH` | `~/.shioaji` | Custom home directory for token pool, contracts cache, and other state |
| `SJ_TIMEOUT` | `60000` | Solace request-reply timeout in milliseconds |
| `SJ_CONTRACTS_PATH` | (falls back to `SJ_HOME_PATH` > `~/.shioaji` > cwd) | Override contracts cache directory. Set to a writable path if the default is read-only. |

### Server 伺服器

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `SJ_PRODUCTION` | `false` | Enable production mode. Default is simulation. |
| `SJ_HTTP_ADDR` | `127.0.0.1:8080` | Server HTTP bind address. Priority: `SJ_HTTP_ADDR` > `SJ_BIND_ADDR` > `BIND_ADDR` > `127.0.0.1:8080` |
| `SJ_HTTP_CORS` | `true` | Enable CORS headers. Also reads `SJ_CORS` and `ENABLE_CORS` as fallbacks. |
| `SJ_HTTP_TIMEOUT` | `30` | HTTP request timeout in seconds. Also reads `TIMEOUT_SECONDS` as fallback. |
| `SJ_HTTP_LOG` | `true` | Enable HTTP request logging. Also reads `SJ_REQUEST_LOG` and `ENABLE_LOGGING` as fallbacks. |

### Unix Domain Socket (Unix only)

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `SJ_UDS_PATH` | `<session_dir>/server-<port>.sock` | Custom Unix domain socket path |
| `SJ_UDS_DISABLE` | `false` | Disable UDS listener entirely (HTTP only) |

### OpenAPI Documentation

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `ENABLE_OPENAPI` | `true` | Enable OpenAPI/Swagger docs endpoint |
| `OPENAPI_PATH` | `/docs` | URL path for the OpenAPI docs page |

### Legacy / Alias 舊版別名

| Variable 變數 | Alias for 等同於 |
|---|---|
| `SJ_BIND_ADDR` | `SJ_HTTP_ADDR` (lower priority fallback) |
| `BIND_ADDR` | `SJ_HTTP_ADDR` (lowest priority fallback) |
| `SJ_CORS` | `SJ_HTTP_CORS` (fallback) |
| `ENABLE_CORS` | `SJ_HTTP_CORS` (fallback) |
| `TIMEOUT_SECONDS` | `SJ_HTTP_TIMEOUT` (fallback) |
| `SJ_REQUEST_LOG` | `SJ_HTTP_LOG` (fallback) |
| `ENABLE_LOGGING` | `SJ_HTTP_LOG` (fallback) |

### Example .env File 範例 .env 檔案

```env
SJ_API_KEY=your_api_key
SJ_SEC_KEY=your_secret_key
SJ_CA_PATH=/path/to/Sinopac.pfx
SJ_CA_PASSWD=your_ca_password
SJ_PRODUCTION=false
```

---

## Login 登入

### Python: `api.login()` method

The Python binding authenticates via `api.login(api_key=..., secret_key=...)`. This performs token-based login internally.
Python 透過 `api.login(api_key=..., secret_key=...)` 進行認證。內部使用 token-based 登入。

```python
import shioaji as sj

api = sj.Shioaji()
accounts = api.login(
    api_key="your_api_key",
    secret_key="your_secret_key",
)
print(accounts)
```

**Sync login signature:**
```python
api.login(
    api_key: str,
    secret_key: str,
    fetch_contract: bool = True,       # Auto-fetch contracts after login
    contracts_timeout: int = 0,        # 0 = async (background), >0 = blocking (ms)
    contracts_cb: Callable = None,     # Callback after contracts loaded
    subscribe_trade: bool = True,      # Auto-subscribe to trade events
    receive_window: int = 30000,       # Token receive window (ms)
) -> List[Account]
```

**Async login signature:**
```python
await api.login(
    api_key: str,
    secret_key: str,
    fetch_contract: bool = True,
    subscribe_trade: bool = True,
    receive_window: int = 30000,
) -> List[Account]
```

Note: `contracts_timeout` and `contracts_cb` are only available in the sync client. The async client always loads contracts non-blocking.

### CLI / Server: Environment Variables

The CLI and HTTP server read credentials from `SJ_API_KEY` and `SJ_SEC_KEY` environment variables. Authentication happens automatically on startup.
CLI 和 HTTP 伺服器從 `SJ_API_KEY` 和 `SJ_SEC_KEY` 環境變數讀取憑證，啟動時自動認證。

```bash
# Start server (reads SJ_API_KEY and SJ_SEC_KEY from env or .env)
# 啟動伺服器（從環境變數或 .env 讀取 SJ_API_KEY 和 SJ_SEC_KEY）
shioaji server

# Or inline
SJ_API_KEY=xxx SJ_SEC_KEY=yyy shioaji server
```

### Token Reuse 令牌重用

After login, the token is cached to `SJ_HOME_PATH` (default `~/.shioaji`). Subsequent logins with the same credentials reuse the cached token if it has not expired, avoiding unnecessary API calls.
登入後，令牌快取到 `SJ_HOME_PATH`（預設 `~/.shioaji`）。使用相同憑證的後續登入會重用未過期的快取令牌。

---

## Python Sync vs Async 同步與異步

RShioaji provides two Python client classes:
RShioaji 提供兩個 Python 客戶端類別：

### `Shioaji` (Sync 同步)

Standard synchronous client. Methods block until complete.
標準同步客戶端。方法會阻塞直到完成。

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)
accounts = api.login(api_key="xxx", secret_key="yyy")

# All methods are blocking 所有方法都是阻塞的
snapshots = api.snapshots([api.Contracts.Stocks["2330"]])
```

### `ShioajiAsync` (Async 異步)

True async/await client. All I/O methods return awaitables.
真正的 async/await 客戶端。所有 I/O 方法返回 awaitable。

```python
import shioaji as sj
import asyncio

async def main():
    api = sj.ShioajiAsync(simulation=True)
    accounts = await api.login(api_key="xxx", secret_key="yyy")

    # All I/O methods are async 所有 I/O 方法都是異步的
    snapshots = await api.snapshots([api.Contracts.Stocks["2330"]])

    # Async callbacks for streaming data 串流資料的異步回呼
    async def on_tick(tick):
        print(tick)
    api.set_on_tick_stk_v1_callback(on_tick)

asyncio.run(main())
```

### Key Differences 主要差異

| Feature 功能 | `Shioaji` (Sync) | `ShioajiAsync` (Async) |
|---|---|---|
| Method calls 方法呼叫 | Blocking 阻塞 | `await` / `Awaitable` |
| Callbacks 回呼 | Regular functions 一般函式 | `async def` coroutines 協程 |
| Login extra params 登入額外參數 | `contracts_timeout`, `contracts_cb` | (none) |
| Data reception 資料接收 | Callback or Receiver | Callback or Receiver |
| Internal 內部 | `runtime.block_on()` | `future_into_py()` |

---

## Account Setup 帳戶設定

After login, the API auto-selects default stock and futures accounts. You can query and override them.
登入後，API 自動選擇預設的股票和期貨帳戶。可以查詢和覆蓋。

### List Accounts 列出帳戶

```python
accounts = api.list_accounts()
for acc in accounts:
    print(f"{acc.account_type} {acc.broker_id}-{acc.account_id} ({acc.person_id})")
```

### Default Account Properties 預設帳戶屬性

```python
# Auto-selected after login 登入後自動選擇
stock_acc = api.stock_account      # First stock (S-type) account
futopt_acc = api.futopt_account    # First futures/options (F-type) account
```

### Override Default Account 覆蓋預設帳戶

```python
accounts = api.list_accounts()
# Set a specific account as default 設定特定帳戶為預設
api.set_default_account(accounts[1])
```

### Account Fields 帳戶欄位

- `account_type` -- `"S"` (Stock) or `"F"` (Futures/Options)
- `person_id` -- ID number of the account holder
- `broker_id` -- Broker identifier
- `account_id` -- Account number
- `signed` -- Whether the account has signed the API agreement
- `username` -- Account holder name

---

## Common Constants 常用常數

Import enums from the `shioaji` module. These are used for orders, contracts, and subscriptions.
從 `shioaji` 模組匯入列舉。用於下單、合約和訂閱。

### SecurityType 證券類型

```python
from shioaji import SecurityType

SecurityType.IND   # Index 指數
SecurityType.STK   # Stock 股票
SecurityType.FUT   # Futures 期貨
SecurityType.OPT   # Option 選擇權
```

### Exchange 交易所

```python
from shioaji import Exchange

Exchange.TSE       # Taiwan Stock Exchange 臺灣證券交易所
Exchange.OTC       # Over-the-Counter 櫃檯買賣中心
Exchange.OES       # Emerging Stock 興櫃
Exchange.TAIFEX    # Taiwan Futures Exchange 臺灣期貨交易所
Exchange.TIM       # TIM
```

### Action 買賣方向

```python
from shioaji import Action

Action.Buy         # Buy 買進
Action.Sell        # Sell 賣出
```

### OrderType 委託類型

```python
from shioaji import OrderType

OrderType.ROD      # Rest of Day 當日有效
OrderType.IOC      # Immediate or Cancel 立即成交否則取消
OrderType.FOK      # Fill or Kill 全部成交否則取消
```

### StockPriceType 股票價格類型

```python
from shioaji import StockPriceType

StockPriceType.LMT   # Limit order 限價
StockPriceType.MKT   # Market order 市價
```

### FuturesPriceType 期貨價格類型

```python
from shioaji import FuturesPriceType

FuturesPriceType.LMT   # Limit order 限價
FuturesPriceType.MKT   # Market order 市價
FuturesPriceType.MKP   # Market price (range market order) 範圍市價
```

### StockOrderLot 股票委託單位

```python
from shioaji import StockOrderLot

StockOrderLot.Common       # Regular lot 整股
StockOrderLot.BlockTrade   # Block trade 鉅額交易
StockOrderLot.Fixing       # Fixing session 定盤
StockOrderLot.Odd          # Odd lot (after-hours) 盤後零股
StockOrderLot.IntradayOdd  # Intraday odd lot 盤中零股
```

### StockOrderCond 股票委託條件

```python
from shioaji import StockOrderCond

StockOrderCond.Cash           # Cash 現股
StockOrderCond.Netting        # Netting 沖銷
StockOrderCond.MarginTrading  # Margin trading 融資
StockOrderCond.ShortSelling   # Short selling 融券
StockOrderCond.Emerging       # Emerging market 興櫃
```

### FuturesOCType 期貨開平倉類型

```python
from shioaji import FuturesOCType

FuturesOCType.Auto      # Auto 自動
FuturesOCType.New       # New position 新倉
FuturesOCType.Cover     # Cover/close position 平倉
FuturesOCType.DayTrade  # Day trade 當沖
```

### QuoteType 報價類型

```python
from shioaji import QuoteType

QuoteType.Tick     # Tick data 逐筆成交
QuoteType.BidAsk   # Bid/Ask data 五檔報價
QuoteType.Quote    # Quote data (legacy) 報價資料
```

---

## Simulation vs Production Mode 模擬與正式模式

By default, RShioaji runs in **simulation mode** (paper trading). This is safe for testing and development.
預設 RShioaji 使用**模擬模式**（模擬交易）。適合測試和開發。

### Setting the Mode 設定模式

**Python:**
```python
# Simulation (default) 模擬模式（預設）
api = sj.Shioaji(simulation=True)
api = sj.Shioaji()  # Also simulation 也是模擬

# Production 正式模式
api = sj.Shioaji(simulation=False)
```

**CLI / Server:**
```bash
# Simulation (default) 模擬模式（預設）
shioaji server

# Production 正式模式
shioaji server --production
shioaji server --prod

# Or via env var 或透過環境變數
SJ_PRODUCTION=true shioaji server
```

### Features with Simulation Guards 模擬模式限制

The following features behave differently or are unavailable in simulation mode:
以下功能在模擬模式下行為不同或不可用：

**Returns empty/default in simulation 模擬模式返回空值/預設值:**

- `account_balance` -- returns default AccountBalance
- `margin` -- returns default Margin
- `settlements` / `list_settlements` -- returns empty list / default
- `trading_limits` -- returns default TradingLimits
- `list_position_detail` -- returns empty list
- `list_profit_loss_detail` -- returns empty list
- `list_profit_loss_summary` -- returns empty summary
- `order_deal_records` -- returns empty list
- `reserve_stocks_summary` -- returns empty summary
- `reserve_stocks_detail` -- returns empty detail
- `earmark_stocks_detail` -- returns empty detail
- `reserve_stock` -- returns default response
- `earmark_stock` -- returns default response

**Errors in simulation 模擬模式回傳錯誤:**

- `place_comboorder` -- combo orders not available in paper/simulation mode
- `cancel_comboorder` -- combo orders not available in paper/simulation mode
- `update_combostatus` -- combo orders not available in paper/simulation mode

**Uses paper endpoints 使用模擬端點:**

- Order operations (`place_order`, `cancel_order`, `update_order`, `update_status`) -- routed to paper trading endpoints
- Portfolio operations (`list_positions`, `list_profit_loss`) -- routed to paper portfolio endpoints

**Skips CA signing 跳過 CA 簽章:**

- `sign_for_account` returns empty string in simulation (no CA certificate needed for paper orders)

**Fully available in simulation 模擬模式完全可用:**

- Market data: `subscribe`, `snapshots`, `ticks`, `kbars`, `credit_enquires`, `scanners`
- Contracts: `Contracts`, `load_contracts`
- Basic orders: `place_order`, `cancel_order`, `update_order`, `update_status`, `list_trades`

---

## CA Certificate Activation 憑證啟用

A CA certificate is required for placing orders in **production mode**. In simulation mode, CA signing is skipped automatically.
在**正式模式**下單需要 CA 憑證。模擬模式會自動跳過 CA 簽章。

### Activate CA 啟用憑證

**Python (sync):**
```python
result = api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="your_password",
    person_id=None,          # Optional: for multi-account (reserved)
)
# Returns True on success 成功返回 True
```

**Python (async):**
```python
result = await api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="your_password",
    person_id=None,
)
```

**CLI / Server:**
The server reads `SJ_CA_PATH` and `SJ_CA_PASSWD` environment variables for automatic CA activation.
伺服器從 `SJ_CA_PATH` 和 `SJ_CA_PASSWD` 環境變數自動啟用 CA。

### Check CA Expiry 查看憑證到期時間

```python
from datetime import datetime

expire_time: datetime = api.get_ca_expiretime(person_id="A123456789")
print(f"CA expires: {expire_time}")
```

### CA Workflow 憑證流程

1. **Download** the `.pfx` certificate from the SinoPac API management page
   從永豐金 API 管理頁面下載 `.pfx` 憑證
2. **Store** the file path and password securely (`.env` file or secret manager)
   安全存放檔案路徑和密碼（`.env` 檔案或密鑰管理器）
3. **Activate** after login and before placing production orders
   在登入後、正式下單前啟用
4. **Renew** before expiry using `get_ca_expiretime()` to check
   使用 `get_ca_expiretime()` 檢查，到期前更新

### Complete Production Setup 完整正式環境設定

```python
import shioaji as sj
import os

# Production mode 正式模式
api = sj.Shioaji(simulation=False)

# Login 登入
api.login(
    api_key=os.environ["SJ_API_KEY"],
    secret_key=os.environ["SJ_SEC_KEY"],
)

# Activate CA (required for production orders)
# 啟用 CA（正式下單必要）
api.activate_ca(
    ca_path=os.environ["SJ_CA_PATH"],
    ca_passwd=os.environ["SJ_CA_PASSWD"],
)

# Now ready for live trading
# 現在可以進行正式交易
print(f"Stock account: {api.stock_account}")
print(f"Futopt account: {api.futopt_account}")
```
