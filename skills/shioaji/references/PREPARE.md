# Preparation 準備工作

This document covers account setup, API key application, and testing environment.
本文件說明開戶、API 金鑰申請和測試環境設定。

---

## Overview 概覽

Before using Shioaji, complete these steps:
使用 Shioaji 前，請完成以下步驟：

1. **Open Account 開立帳戶** - Apply for Sinopac securities account
2. **Apply API Key 申請金鑰** - Get API Key and Secret Key
3. **Download Certificate 下載憑證** - Get CA certificate for trading
4. **Install uv 安裝 uv** - Install Python environment manager
5. **Create Project 建立專案** - Initialize project with uv
6. **Configure Environment 設定環境** - Set up environment variables
7. **Test in Simulation 模擬測試** - Verify setup in simulation mode

---

## Open Account 開立帳戶

Apply for a Sinopac securities account:
申請永豐金證券帳戶：

- **Online Application 線上開戶**: https://sinotrade.github.io/tutor/prepare/open_account
- Required documents 所需文件: ID card, second ID, bank account

---

## Apply API Key 申請金鑰

### Step 1: Access API Management 進入 API 管理

Go to Sinopac personal service page:
前往永豐金個人服務頁面：

https://www.sinotrade.com.tw/newweb/PythonAPIKey/

### Step 2: Create API Key 建立 API Key

1. Click "Add API KEY" 點擊「新增 API KEY」
2. Complete 2FA verification 完成雙重驗證（手機或 Email）
3. Configure key settings 設定金鑰選項：
   - **Expiration 到期時間** - Set key validity period
   - **Permissions 權限** - Market/Data, Account, Trading
   - **Accounts 帳戶** - Select allowed accounts
   - **Production 正式環境** - Enable for live trading
   - **IP Whitelist IP 白名單** - Restrict allowed IPs (recommended)

### Step 3: Save Keys 保存金鑰

After creation, you'll receive:
建立後會取得：

- **API Key** - Public identifier
- **Secret Key** - Private key (shown only once! 只顯示一次！)

```python
# Store in environment variables 存放在環境變數中
API_KEY = "your_api_key"
SECRET_KEY = "your_secret_key"
```

---

## Download Certificate 下載憑證

### Step 1: Download CA Certificate 下載 CA 憑證

1. Go to API management page 進入 API 管理頁面
2. Click "Download Certificate" 點擊「下載憑證」
3. Save the `.pfx` file 儲存 `.pfx` 檔案

### Step 2: Store Certificate 存放憑證

```python
# Certificate path and password 憑證路徑與密碼
CA_CERT_PATH = "/path/to/Sinopac.pfx"
CA_PASSWORD = "your_ca_password"
```

---

## Install uv 安裝 uv

uv is the recommended tool for managing Python environment.
uv 是推薦的 Python 環境管理工具。

```bash
# Linux / MacOS
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

More info 更多資訊: https://docs.astral.sh/uv/

---

## Create Project 建立專案

### Step 1: Initialize Project 初始化專案

```bash
# Create packaged application 建立打包應用程式
uv init sj-trading --package

cd sj-trading
```

Project structure 專案結構:

```
sj-trading/
├── .python-version
├── README.md
├── pyproject.toml
└── src/
    └── sj_trading/
        └── __init__.py
```

### Step 2: Add Shioaji 加入 Shioaji

```bash
uv add shioaji
```

### Step 3: Verify Installation 驗證安裝

Edit `src/sj_trading/__init__.py`:
編輯 `src/sj_trading/__init__.py`：

```python
import shioaji as sj

def hello():
    api = sj.Shioaji()
    print(f"Shioaji Version: {sj.__version__}")
    print("Shioaji API created successfully!")
    return api
```

Add command to `pyproject.toml`:
在 `pyproject.toml` 加入命令：

```toml
[project.scripts]
hello = "sj_trading:hello"
```

Run 執行:

```bash
uv run hello
```

Output 輸出:

```
Shioaji Version: 1.x.x
Shioaji API created successfully!
```

### Use Jupyter 使用 Jupyter

```bash
# Add ipykernel to dev dependencies 加入開發依賴
uv add --dev ipykernel

# Register kernel 註冊 kernel
uv run ipython kernel install --user --name=sj-trading

# Start Jupyter Lab 啟動 Jupyter Lab
uv run --with jupyter jupyter lab
```

---

## Environment Variables 環境變數設定

### Using .env File 使用 .env 檔案

Create `.env` file in project root:
在專案根目錄建立 `.env` 檔案：

```
API_KEY=your_api_key
SECRET_KEY=your_secret_key
CA_CERT_PATH=/path/to/Sinopac.pfx
CA_PASSWORD=your_ca_password
```

### Load Environment Variables 載入環境變數

```python
import os
from dotenv import load_dotenv

load_dotenv()

api_key = os.environ["API_KEY"]
secret_key = os.environ["SECRET_KEY"]
ca_path = os.environ["CA_CERT_PATH"]
ca_password = os.environ["CA_PASSWORD"]
```

Install python-dotenv 安裝 python-dotenv：

```bash
uv add python-dotenv
```

---

## Simulation Mode 模擬環境

Test your setup in simulation mode before live trading:
在正式交易前，先在模擬環境測試：

```python
import shioaji as sj

# Enable simulation mode 啟用模擬模式
api = sj.Shioaji(simulation=True)

# Login 登入
api.login(
    api_key=os.environ["API_KEY"],
    secret_key=os.environ["SECRET_KEY"],
)

# Activate CA 啟用憑證
api.activate_ca(
    ca_path=os.environ["CA_CERT_PATH"],
    ca_passwd=os.environ["CA_PASSWORD"],
)

print("Login successful! 登入成功！")
```

### Available APIs in Simulation 模擬環境可用 API

**Data 資料:**
- `quote.subscribe` / `quote.unsubscribe`
- `ticks`, `kbars`, `snapshots`
- `short_stock_sources`, `credit_enquires`, `scanners`

**Order 委託:**
- `place_order`, `update_order`, `cancel_order`
- `update_status`, `list_trades`

**Account 帳務:**
- `list_positions`, `list_profit_loss`

---

## Testing Project 測試專案

### Demo Project 範例專案

Clone the official demo project:
複製官方範例專案：

```bash
git clone https://github.com/Sinotrade/sj-trading-demo.git
cd sj-trading-demo
```

### Stock Order Testing 股票下單測試

```python
import shioaji as sj
from shioaji.constant import Action, StockPriceType, OrderType
import os

def testing_stock_ordering():
    # Login to simulation 登入模擬環境
    api = sj.Shioaji(simulation=True)
    api.login(
        api_key=os.environ["API_KEY"],
        secret_key=os.environ["SECRET_KEY"],
    )
    api.activate_ca(
        ca_path=os.environ["CA_CERT_PATH"],
        ca_passwd=os.environ["CA_PASSWORD"],
    )

    # Get contract 取得合約
    contract = api.Contracts.Stocks["2890"]
    print(f"Contract: {contract}")

    # Create order 建立訂單
    order = sj.order.StockOrder(
        action=Action.Buy,
        price=contract.reference,  # Reference price 參考價
        quantity=1,
        price_type=StockPriceType.LMT,
        order_type=OrderType.ROD,
        account=api.stock_account,
    )

    # Place order 下單
    trade = api.place_order(contract=contract, order=order)
    print(f"Trade: {trade}")

    # Update status 更新狀態
    api.update_status()
    print(f"Status: {trade.status}")
```

### Futures Order Testing 期貨下單測試

```python
from shioaji.constant import FuturesPriceType, FuturesOCType

def testing_futures_ordering():
    api = sj.Shioaji(simulation=True)
    api.login(
        api_key=os.environ["API_KEY"],
        secret_key=os.environ["SECRET_KEY"],
    )
    api.activate_ca(
        ca_path=os.environ["CA_CERT_PATH"],
        ca_passwd=os.environ["CA_PASSWORD"],
    )

    # Get futures contract 取得期貨合約
    contract = api.Contracts.Futures["TXFR1"]  # Near month 近月
    print(f"Contract: {contract}")

    # Create futures order 建立期貨訂單
    order = sj.order.FuturesOrder(
        action=Action.Buy,
        price=contract.reference,
        quantity=1,
        price_type=FuturesPriceType.LMT,
        order_type=OrderType.ROD,
        octype=FuturesOCType.Auto,
        account=api.futopt_account,
    )

    # Place order 下單
    trade = api.place_order(contract=contract, order=order)
    print(f"Trade: {trade}")

    api.update_status()
    print(f"Status: {trade.status}")
```

### Run with uv 使用 uv 執行

```bash
# Add test commands to pyproject.toml
# 將測試命令加入 pyproject.toml

[project.scripts]
stock_testing = "sj_trading.testing_flow:testing_stock_ordering"
futures_testing = "sj_trading.testing_flow:testing_futures_ordering"

# Run tests 執行測試
uv run stock_testing
uv run futures_testing
```

---

## Production Environment 正式環境

After testing, switch to production:
測試完成後，切換到正式環境：

```python
# Remove simulation=True for production
# 正式環境移除 simulation=True
api = sj.Shioaji()  # Production mode 正式模式

api.login(
    api_key=os.environ["API_KEY"],
    secret_key=os.environ["SECRET_KEY"],
)
```

---

## Checklist 檢查清單

Before going live 上線前確認：

- [ ] Account opened 帳戶已開立
- [ ] API Key created 已建立 API Key
- [ ] Certificate downloaded 已下載憑證
- [ ] Terms signed 已簽署條款
- [ ] Simulation tested 已完成模擬測試
- [ ] IP whitelist configured 已設定 IP 白名單

---

## Reference 參考資料

- Account opening 開戶: https://sinotrade.github.io/tutor/prepare/open_account
- API Key 金鑰: https://sinotrade.github.io/tutor/prepare/token
- Terms 條款: https://sinotrade.github.io/tutor/prepare/terms
- Demo project 範例專案: https://github.com/Sinotrade/sj-trading-demo
