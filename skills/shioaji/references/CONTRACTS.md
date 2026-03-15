# Contracts 合約

This document covers how to access and use contract objects in Shioaji.
本文件說明如何在 Shioaji 中存取和使用合約物件。

---

## Overview 概覽

Contracts are automatically downloaded during login. Access them via `api.Contracts`.
合約會在登入時自動下載，透過 `api.Contracts` 存取。

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Contracts are now available 合約已可使用
```

---

## Stock Contracts 股票合約

### Access by Symbol 以代碼存取

```python
# By stock code 以股票代碼
tsmc = api.Contracts.Stocks["2330"]      # TSMC 台積電
hon_hai = api.Contracts.Stocks["2317"]   # Hon Hai 鴻海

# ETF
etf_0050 = api.Contracts.Stocks["0050"]  # Taiwan 50 ETF
```

### Access by Exchange 以交易所存取

```python
# TSE (Taiwan Stock Exchange) 上市
tse_stocks = api.Contracts.Stocks.TSE

# OTC (Over-the-Counter) 上櫃
otc_stocks = api.Contracts.Stocks.OTC
```

### Contract Attributes 合約屬性

```python
contract = api.Contracts.Stocks["2330"]

contract.code           # Stock code 股票代碼: "2330"
contract.symbol         # Full symbol 完整代號
contract.name           # Company name 公司名稱
contract.category       # Category 類別
contract.exchange       # Exchange 交易所: "TSE" or "OTC"
contract.limit_up       # Price limit up 漲停價
contract.limit_down     # Price limit down 跌停價
contract.reference      # Reference price 參考價
contract.update_date    # Last update date 更新日期
contract.day_trade      # Day trade allowed 可當沖: "Yes"/"No"
```

---

## Futures Contracts 期貨合約

### Access Futures 存取期貨

```python
# By futures code 以期貨代碼
tx = api.Contracts.Futures["TXF"]     # Taiwan Index Futures 台指期
mtx = api.Contracts.Futures["MXF"]    # Mini Taiwan Index Futures 小台指
txo = api.Contracts.Futures["TXO"]    # Taiwan Index Options 台指選

# Current month contract 當月合約
txf_current = api.Contracts.Futures["TXFC0"]  # C0 = current month 近月

# Specific month 指定月份
txf_202401 = api.Contracts.Futures["TXF202401"]
```

### Futures Contract Naming 期貨合約命名規則

| Pattern 格式 | Example 範例 | Description 說明 |
|--------------|--------------|------------------|
| `{CODE}C0` | `TXFC0` | Current month 近月 |
| `{CODE}C1` | `TXFC1` | Next month 次月 |
| `{CODE}{YYYYMM}` | `TXF202401` | Specific month 指定月份 |

### Futures Attributes 期貨屬性

```python
contract = api.Contracts.Futures["TXFC0"]

contract.code           # Futures code 期貨代碼
contract.symbol         # Full symbol 完整代號
contract.name           # Contract name 合約名稱
contract.category       # Category 類別
contract.delivery_month # Delivery month 交割月份
contract.delivery_date  # Delivery date 交割日
contract.underlying_kind # Underlying type 標的類型
contract.limit_up       # Price limit up 漲停價
contract.limit_down     # Price limit down 跌停價
contract.reference      # Reference price 參考價
contract.update_date    # Update date 更新日期
```

---

## Options Contracts 選擇權合約

### Access Options 存取選擇權

```python
# Taiwan Index Options 台指選擇權
txo = api.Contracts.Options["TXO"]

# Specific contract 指定合約
# Format: {CODE}{YYYYMM}{C/P}{Strike}
txo_call = api.Contracts.Options["TXO202401C18000"]  # Call @ 18000
txo_put = api.Contracts.Options["TXO202401P17000"]   # Put @ 17000
```

### Options Contract Naming 選擇權合約命名

| Part 部分 | Description 說明 | Example 範例 |
|-----------|------------------|--------------|
| Code 代碼 | Product code 商品代碼 | `TXO` |
| YYYYMM | Expiry month 到期月 | `202401` |
| C/P | Call or Put 買權/賣權 | `C` or `P` |
| Strike | Strike price 履約價 | `18000` |

### Options Attributes 選擇權屬性

```python
contract = api.Contracts.Options["TXO202401C18000"]

contract.code           # Option code 選擇權代碼
contract.symbol         # Full symbol 完整代號
contract.name           # Contract name 合約名稱
contract.category       # Category 類別
contract.delivery_month # Delivery month 到期月份
contract.strike_price   # Strike price 履約價
contract.option_right   # Call or Put 買權/賣權
contract.limit_up       # Price limit up 漲停價
contract.limit_down     # Price limit down 跌停價
contract.reference      # Reference price 參考價
contract.update_date    # Update date 更新日期
```

---

## Index Contracts 指數合約

### Access Index 存取指數

```python
# Taiwan Weighted Index 加權指數
tse_index = api.Contracts.Indexs["TSE001"]

# OTC Index 櫃買指數
otc_index = api.Contracts.Indexs["OTC101"]
```

---

## Fetching All Contracts 取得所有合約

### List All Stocks 列出所有股票

```python
# All stocks 所有股票
all_stocks = [c for c in api.Contracts.Stocks]

# Filter by exchange 依交易所篩選
tse_stocks = [c for c in api.Contracts.Stocks if c.exchange == "TSE"]
otc_stocks = [c for c in api.Contracts.Stocks if c.exchange == "OTC"]

# Filter by day trade 依可當沖篩選
day_trade_stocks = [c for c in api.Contracts.Stocks if c.day_trade == "Yes"]
```

### List All Futures 列出所有期貨

```python
all_futures = [c for c in api.Contracts.Futures]
```

### List All Options 列出所有選擇權

```python
all_options = [c for c in api.Contracts.Options]
```

---

## Contract Snapshots 合約快照

Get real-time snapshot for contracts:
取得合約的即時快照：

```python
# Single contract 單一合約
snapshot = api.snapshots([api.Contracts.Stocks["2330"]])

# Multiple contracts (up to 500) 多個合約（最多 500 個）
contracts = [
    api.Contracts.Stocks["2330"],
    api.Contracts.Stocks["2317"],
    api.Contracts.Futures["TXFC0"],
]
snapshots = api.snapshots(contracts)

for snap in snapshots:
    print(f"{snap.code}: {snap.close} ({snap.change_price})")
```

### Snapshot Attributes 快照屬性

```python
snap.ts           # Timestamp 時間戳
snap.code         # Contract code 合約代碼
snap.exchange     # Exchange 交易所
snap.open         # Open price 開盤價
snap.high         # High price 最高價
snap.low          # Low price 最低價
snap.close        # Close/Last price 收盤/最新價
snap.change_price # Price change 漲跌
snap.change_rate  # Change rate % 漲跌幅
snap.volume       # Volume 成交量
snap.total_volume # Total volume 總成交量
snap.amount       # Amount 成交金額
snap.total_amount # Total amount 總成交金額
snap.buy_price    # Best bid 最佳買價
snap.buy_volume   # Bid volume 買量
snap.sell_price   # Best ask 最佳賣價
snap.sell_volume  # Ask volume 賣量
```

---

## Contract Update 合約更新

Contracts can be updated manually if needed:
如需要可手動更新合約：

```python
# Fetch latest contract info 取得最新合約資訊
api.fetch_contracts(contract_download=True)
```
