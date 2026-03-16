---
name: shioaji
description: |
  ALWAYS USE THIS SKILL when working with Shioaji, SinoPac, or Taiwan financial markets.
  Covers: placing/modifying/canceling stock/futures/options orders (buy, sell, limit, market, ROD, IOC, FOK, margin, short selling, odd lot, combo orders), real-time streaming tick & bidask data, historical kbars & ticks, snapshots, account balance/margin/positions/P&L queries, watchlists, scanners, reserve orders, and automated trading systems on TWSE/TPEX/TAIFEX with Python.
  使用 Shioaji、永豐金證券、台灣金融市場交易時務必使用本技能。
  涵蓋：股票/期貨/選擇權下單/改單/刪單（買進、賣出、限價、市價、ROD、IOC、FOK、融資、融券、零股、組合單）、即時行情串流 Tick/五檔報價、歷史 K 線與 Tick、快照、帳務餘額/保證金/持倉/損益查詢、自選股、掃描器排行、預收券款、Python 自動交易系統開發（TWSE/TPEX/TAIFEX）。
---

# Shioaji Trading API

Shioaji is SinoPac's Python API for trading Taiwan financial markets (stocks, futures, options).
Shioaji 是永豐金證券提供的 Python 交易 API，支援台灣股票、期貨、選擇權市場。

**Official Docs 官方文檔**: https://sinotrade.github.io/
**LLM Reference**: https://sinotrade.github.io/llms-full.txt

---

## Navigation 功能導覽

| Topic 主題 | File 檔案 | Description 說明 |
|------------|-----------|------------------|
| Preparation 準備 | [PREPARE.md](references/PREPARE.md) | Account setup, API keys, testing 開戶/金鑰申請/測試 |
| Contracts 合約 | [CONTRACTS.md](references/CONTRACTS.md) | Stocks, Futures, Options contracts 股票/期貨/選擇權合約 |
| Orders 下單 | [ORDERS.md](references/ORDERS.md) | Place, modify, cancel, combo orders 下單/改單/刪單/組合單 |
| Reserve 預收 | [RESERVE.md](references/RESERVE.md) | Reserve orders for disposition stocks 處置股預收券款 |
| Streaming 行情 | [STREAMING.md](references/STREAMING.md) | Real-time tick & bidask data 即時 Tick/BidAsk 資料 |
| Market Data 市場資料 | [MARKET_DATA.md](references/MARKET_DATA.md) | Historical, snapshot, credit, scanners 歷史資料/快照/資券/掃描器 |
| Accounting 帳務 | [ACCOUNTING.md](references/ACCOUNTING.md) | Balance, margin, P&L, trading limits 餘額/保證金/損益/額度 |
| Watchlist 自選股 | [WATCHLIST.md](references/WATCHLIST.md) | Custom stock lists management 自選股清單管理 |
| Advanced 進階 | [ADVANCED.md](references/ADVANCED.md) | Quote binding, non-blocking, stop orders 報價綁定/非阻塞/觸價 |
| Troubleshooting 問題排解 | [TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) | Common issues and solutions 常見問題與解決 |

---

## Routing Guide 路由指引

Use this to decide which reference file(s) to read based on user intent. For most tasks, load only 1-2 files.
根據使用者意圖決定載入哪個參考檔案，大部分情境只需載入 1-2 個檔案。

| User Intent 使用者意圖 | Load File 載入檔案 |
|------------------------|-------------------|
| First-time setup, install, login, API key, CA certificate, simulation 首次設定/安裝/登入/金鑰/憑證/模擬 | [references/PREPARE.md](references/PREPARE.md) |
| Get contract object, list stocks/futures/options, contract attributes 取得合約/列出股票期貨選擇權/合約屬性 | [references/CONTRACTS.md](references/CONTRACTS.md) |
| Place, modify, cancel orders (stock/futures/options), combo orders, order callbacks 下單/改單/刪單/組合單/委託回報 | [references/ORDERS.md](references/ORDERS.md) |
| Reserve shares for disposition/attention stocks 處置股/注意股預收券款 | [references/RESERVE.md](references/RESERVE.md) |
| Subscribe real-time quotes, tick/bidask callbacks, event handling 訂閱即時行情/Tick/五檔回調/事件處理 | [references/STREAMING.md](references/STREAMING.md) |
| Historical ticks/kbars, snapshots, credit enquiries, short sources, scanners 歷史Tick/K線/快照/資券/券源/掃描器 | [references/MARKET_DATA.md](references/MARKET_DATA.md) |
| Account balance, margin, positions, P&L, settlements, trading limits 帳務餘額/保證金/持倉/損益/交割/額度 | [references/ACCOUNTING.md](references/ACCOUNTING.md) |
| Custom watchlist CRUD, sync contracts 自選股清單管理/同步合約 | [references/WATCHLIST.md](references/WATCHLIST.md) |
| Non-blocking mode, quote binding, stop orders 非阻塞模式/報價綁定/觸價委託 | [references/ADVANCED.md](references/ADVANCED.md) |
| Errors, connection issues, rate limits, environment config 錯誤/連線問題/速率限制/環境設定 | [references/TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) |

---

## Quick Start 快速入門

### Installation 安裝

```bash
# pip
pip install shioaji

# uv (recommended 推薦)
uv add shioaji

# with speed optimization 速度優化版
uv add shioaji --extra speed

# Docker
docker run -it sinotrade/shioaji:latest
```

### Login & Activate CA 登入與憑證啟用

```python
import shioaji as sj

api = sj.Shioaji()

# Login with API Key 使用 API Key 登入
accounts = api.login(
    api_key="YOUR_API_KEY",
    secret_key="YOUR_SECRET_KEY"
)

# Activate CA certificate 啟用憑證 (required for placing orders 下單必須)
api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="YOUR_CA_PASSWORD",
)
```

### Simulation Mode 模擬模式

Test API without real money. 使用模擬環境測試 API。

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")
```

**Available in simulation 模擬模式可用功能:**
- Quote: subscribe, unsubscribe, ticks, kbars, snapshots
- Order: place_order, update_order, cancel_order, update_status, list_trades
- Account: list_positions, list_profit_loss
- Data: short_stock_sources, credit_enquires, scanners

### Simple Order Example 簡單下單範例

```python
# Get contract 取得合約
contract = api.Contracts.Stocks["2330"]  # TSMC 台積電

# Create order 建立訂單
order = api.Order(
    price=580,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    account=api.stock_account,
)

# Place order 下單
trade = api.place_order(contract, order)
```

---

## Common Constants 常用常數

### Action 買賣方向
```python
sj.constant.Action.Buy   # 買進
sj.constant.Action.Sell  # 賣出
```

### Stock Price Type 股票價格類型
```python
sj.constant.StockPriceType.LMT  # Limit 限價
sj.constant.StockPriceType.MKT  # Market 市價
sj.constant.StockPriceType.MKP  # Range Market 範圍市價
```

### Futures Price Type 期貨價格類型
```python
sj.constant.FuturesPriceType.LMT  # Limit 限價
sj.constant.FuturesPriceType.MKT  # Market 市價
sj.constant.FuturesPriceType.MKP  # Range Market 範圍市價
```

### Order Type 委託條件
```python
sj.constant.OrderType.ROD  # Rest of Day 當日有效
sj.constant.OrderType.IOC  # Immediate or Cancel 立即成交否則取消
sj.constant.OrderType.FOK  # Fill or Kill 全部成交否則取消
```

### Stock Order Lot 股票交易單位
```python
sj.constant.StockOrderLot.Common      # Regular 整股 (1000 shares)
sj.constant.StockOrderLot.Odd         # After-hours odd lot 盤後零股
sj.constant.StockOrderLot.IntradayOdd # Intraday odd lot 盤中零股
sj.constant.StockOrderLot.Fixing      # Fixing 定盤
```

### Order Condition 信用交易條件
```python
sj.constant.StockOrderCond.Cash          # Cash 現股
sj.constant.StockOrderCond.MarginTrading # Margin 融資
sj.constant.StockOrderCond.ShortSelling  # Short 融券
```

### Quote Type 報價類型
```python
sj.constant.QuoteType.Tick    # Tick data 逐筆成交
sj.constant.QuoteType.BidAsk  # Bid/Ask data 五檔報價
```

---

## Account Objects 帳戶物件

```python
# Stock account 股票帳戶
api.stock_account

# Futures account 期貨帳戶
api.futopt_account

# List all accounts 列出所有帳戶
api.list_accounts()
```

---

## Rate Limits 流量限制

| Category 類別 | Limit 限制 |
|---------------|------------|
| Daily Traffic 每日流量 | 500MB - 10GB (based on trading volume 依交易量) |
| Quote Query 行情查詢 | 50 requests / 5 sec |
| Accounting Query 帳務查詢 | 25 requests / 5 sec |
| Connections 連線數 | 5 per person ID |
| Daily Logins 每日登入 | 1000 times |

---

## Common Patterns 常用模式

### Subscribe Market Data 訂閱行情

```python
# Subscribe tick data 訂閱逐筆成交
api.quote.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.Tick
)

# Subscribe bidask 訂閱五檔
api.quote.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.BidAsk
)

# Set callback 設定回調
@api.quote.on_quote
def quote_callback(topic, quote):
    print(f"Topic: {topic}, Quote: {quote}")
```

### Query Positions 查詢持倉

```python
# Stock positions 股票持倉
positions = api.list_positions(api.stock_account)

# Futures positions 期貨持倉
positions = api.list_positions(api.futopt_account)
```

### Cancel Order 刪單

```python
api.cancel_order(trade)
```

### Update Order 改單

```python
# Change price 改價
api.update_order(trade=trade, price=590)

# Reduce quantity 減量 (can only reduce 只能減少)
api.update_order(trade=trade, qty=1)
```

---

## Error Handling 錯誤處理

```python
try:
    trade = api.place_order(contract, order)
except Exception as e:
    print(f"Order failed: {e}")

# Check order status 檢查訂單狀態
api.update_status(api.stock_account)
for trade in api.list_trades():
    print(trade.status)
```

---

## Logout 登出

```python
api.logout()
```
