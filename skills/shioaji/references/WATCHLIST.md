# Watchlist 自選股清單

This document covers watchlist management for custom stock/contract lists.
本文件說明自選股清單的管理功能。

---

## Overview 概覽

| Function 函數 | Description 說明 |
|--------------|------------------|
| `fetch_watchlists()` | Get all watchlists 取得所有自選股清單 |
| `get_watchlist()` | Get specific watchlist 取得單個自選股清單 |
| `create_watchlist()` | Create new watchlist 創建自選股清單 |
| `delete_watchlist()` | Delete watchlist 刪除自選股清單 |
| `sync_watchlist()` | Sync (replace) contracts 同步（覆蓋）合約 |
| `watchlist_add_contract()` | Add contracts 新增合約 |
| `watchlist_delete_contract()` | Remove contracts 移除合約 |

---

## Fetch Watchlists 取得自選股清單

### Get All Watchlists 取得所有清單

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Fetch all watchlists 取得所有自選股清單
watchlists = api.fetch_watchlists()

for wl in watchlists:
    print(f"ID: {wl.id}, Name: {wl.name}, Contracts: {len(wl.contracts)}")
```

### fetch_watchlists Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

### Get Single Watchlist 取得單個清單

```python
# Get watchlist by ID 依 ID 取得清單
watchlist = api.get_watchlist("watchlist_id")

print(f"Name: {watchlist.name}")
for contract in watchlist.contracts:
    print(f"  - {contract.code} ({contract.security_type})")
```

### get_watchlist Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `group_id` | `str` | Watchlist ID 自選股清單 ID |
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

---

## Create & Delete 創建與刪除

### Create Watchlist 創建自選股清單

```python
# Create with contracts 建立並加入合約
new_watchlist = api.create_watchlist(
    name="My Watchlist",
    contracts=[
        api.Contracts.Stocks["2330"],
        api.Contracts.Stocks["2317"],
    ]
)

print(f"Created: {new_watchlist.id}")

# Create empty watchlist 建立空白清單
empty_watchlist = api.create_watchlist(name="Empty List")
```

### create_watchlist Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `name` | `str` | Watchlist name 清單名稱 |
| `contracts` | `List[Contract]` | Initial contracts (optional) 初始合約（選填）|
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

### Delete Watchlist 刪除自選股清單

```python
# Delete by ID 依 ID 刪除
deleted = api.delete_watchlist("watchlist_id")

print(f"Deleted: {deleted.name}")
```

### delete_watchlist Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `group_id` | `str` | Watchlist ID to delete 要刪除的清單 ID |
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

---

## Manage Contracts 管理合約

### Add Contracts 新增合約

```python
# Add contracts to watchlist 新增合約到清單
updated = api.watchlist_add_contract(
    group_id="watchlist_id",
    contracts=[
        api.Contracts.Stocks["2454"],
        api.Contracts.Futures.TXF.TXFR1,
    ]
)

print(f"Updated contracts: {len(updated.contracts)}")
```

### watchlist_add_contract Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `group_id` | `str` | Watchlist ID 清單 ID |
| `contracts` | `List[Contract]` | Contracts to add 要新增的合約 |
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

### Remove Contracts 移除合約

```python
# Remove contracts from watchlist 從清單移除合約
updated = api.watchlist_delete_contract(
    group_id="watchlist_id",
    contracts=[api.Contracts.Stocks["2454"]]
)

print(f"Remaining contracts: {len(updated.contracts)}")
```

### watchlist_delete_contract Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `group_id` | `str` | Watchlist ID 清單 ID |
| `contracts` | `List[Contract]` | Contracts to remove 要移除的合約 |
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

### Sync (Replace All) Contracts 同步（覆蓋）合約

```python
# Replace all contracts in watchlist 覆蓋清單中的所有合約
synced = api.sync_watchlist(
    group_id="watchlist_id",
    contracts=[
        api.Contracts.Stocks["2330"],
        api.Contracts.Stocks["2454"],
        api.Contracts.Futures.TXF.TXFR1,
    ]
)

print(f"Synced contracts: {len(synced.contracts)}")
```

### sync_watchlist Parameters 參數

| Parameter 參數 | Type 類型 | Description 說明 |
|---------------|----------|------------------|
| `group_id` | `str` | Watchlist ID 清單 ID |
| `contracts` | `List[Contract]` | Contracts to sync (replaces all) 要同步的合約（覆蓋全部）|
| `timeout` | `int` | Request timeout in ms (Default: 5000) 請求超時毫秒（預設：5000）|
| `cb` | `Callable` | Callback for async mode 非同步回呼函數 |

---

## Watchlist Attributes 自選股屬性

### Watchlist Object 自選股物件

```python
watchlist.id          # str: Watchlist ID 清單 ID
watchlist.person_id   # str: Owner user ID 擁有者 ID
watchlist.name        # str: Watchlist name 清單名稱
watchlist.contracts   # List[BaseContract]: List of contracts 合約列表
```

### Contract in Watchlist 清單中的合約

```python
contract.security_type  # SecurityType: Stock/Future/Option/Index 商品類型
contract.exchange       # Exchange: TSE/OTC/TAIFEX 交易所
contract.code           # str: Contract code 合約代碼
```

---

## Common Use Cases 常見用法

### Monitor Multiple Stocks 監控多檔股票

```python
# Create a tech watchlist 建立科技股清單
tech_watchlist = api.create_watchlist(
    name="Tech Stocks",
    contracts=[
        api.Contracts.Stocks["2330"],  # TSMC
        api.Contracts.Stocks["2454"],  # MediaTek
        api.Contracts.Stocks["2317"],  # Hon Hai
        api.Contracts.Stocks["2308"],  # Delta
    ]
)

# Get snapshots for all contracts 取得所有合約快照
snapshots = api.snapshots([
    api.Contracts.Stocks[c.code]
    for c in tech_watchlist.contracts
    if c.security_type == "STK"
])

for snap in snapshots:
    print(f"{snap.code}: {snap.close} ({snap.change_rate}%)")
```

### Subscribe to Watchlist Quotes 訂閱清單行情

```python
watchlist = api.get_watchlist("watchlist_id")

for contract in watchlist.contracts:
    # Get full contract object 取得完整合約物件
    if contract.security_type.value == "STK":
        full_contract = api.Contracts.Stocks[contract.code]
    elif contract.security_type.value == "FUT":
        full_contract = api.Contracts.Futures[contract.code]

    api.quote.subscribe(full_contract)
```

---

## Reference 參考資料

- Official docs 官方文檔: https://sinotrade.github.io/
