# Watchlist 自選股清單

This document covers watchlist CRUD operations in rshioaji.
本文件說明 rshioaji 中自選股清單的增刪改查功能。

See [HTTP_API.md](HTTP_API.md) for full endpoint details.

**Note:** CLI watchlist commands are NOT implemented. Use Python or HTTP API.
**注意：** CLI 自選股命令尚未實作。請使用 Python 或 HTTP API。

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Fetch All Watchlists 取得所有清單](#fetch-all-watchlists-取得所有清單)
- [Get Watchlist by ID 依 ID 取得清單](#get-watchlist-by-id-依-id-取得清單)
- [Create Watchlist 建立清單](#create-watchlist-建立清單)
- [Delete Watchlist 刪除清單](#delete-watchlist-刪除清單)
- [Sync (Replace) Contracts 同步（覆蓋）合約](#sync-replace-contracts-同步覆蓋合約)
- [Add Contracts 新增合約](#add-contracts-新增合約)
- [Remove Contracts 移除合約](#remove-contracts-移除合約)
- [Watchlist Attributes 自選股屬性](#watchlist-attributes-自選股屬性)
- [HTTP Endpoint Summary HTTP 端點一覽](#http-endpoint-summary-http-端點一覽)

---

## Overview 概覽

| Python Method 方法 | Description 說明 | HTTP Method + Path |
|---------------------|------------------|--------------------|
| `fetch_watchlists()` | Get all watchlists 取得所有清單 | `GET /api/v1/watchlist` |
| `get_watchlist(group_id)` | Get one watchlist 取得單個清單 | `GET /api/v1/watchlist/{id}` |
| `create_watchlist(name, contracts)` | Create new watchlist 建立清單 | `POST /api/v1/watchlist` |
| `delete_watchlist(group_id)` | Delete watchlist 刪除清單 | `DELETE /api/v1/watchlist/{id}` |
| `sync_watchlist(group_id, contracts)` | Replace all contracts 覆蓋所有合約 | `PUT /api/v1/watchlist/{id}` |
| `watchlist_add_contract(group_id, contracts)` | Add contracts 新增合約 | `POST /api/v1/watchlist/{id}/contracts` |
| `watchlist_delete_contract(group_id, contracts)` | Remove contracts 移除合約 | `DELETE /api/v1/watchlist/{id}/contracts` |

---

## Fetch All Watchlists 取得所有清單

### Python Usage Python 用法

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Fetch all watchlists 取得所有自選股清單
watchlists = api.fetch_watchlists()

for wl in watchlists:
    print(f"ID: {wl.id}, Name: {wl.name}")
    for contract in wl.contracts:
        print(f"  - {contract.code} ({contract.security_type})")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback for timeout=0 mode 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X GET http://localhost:8080/api/v1/watchlist
```

---

## Get Watchlist by ID 依 ID 取得清單

### Python Usage Python 用法

```python
watchlist = api.get_watchlist("watchlist_id")

print(f"Name: {watchlist.name}")
for contract in watchlist.contracts:
    print(f"  - {contract.code}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `group_id` | `str` | (required) | Watchlist ID 清單 ID |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X GET http://localhost:8080/api/v1/watchlist/{id}
```

---

## Create Watchlist 建立清單

### Python Usage Python 用法

```python
# Create with contracts 建立並加入合約
new_wl = api.create_watchlist(
    name="My Watchlist",
    contracts=[
        api.Contracts.Stocks["2330"],
        api.Contracts.Stocks["2317"],
    ]
)
print(f"Created: {new_wl.id}")

# Create empty watchlist 建立空白清單
empty_wl = api.create_watchlist(name="Empty List")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `name` | `str` | (required) | Watchlist name 清單名稱 |
| `contracts` | `List[BaseContract]` | `None` | Initial contracts (optional) 初始合約 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/watchlist \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Watchlist",
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2330"},
      {"security_type": "STK", "exchange": "TSE", "code": "2317"}
    ]
  }'
```

---

## Delete Watchlist 刪除清單

### Python Usage Python 用法

```python
deleted = api.delete_watchlist("watchlist_id")
print(f"Deleted: {deleted.name}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `group_id` | `str` | (required) | Watchlist ID to delete 要刪除的清單 ID |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X DELETE http://localhost:8080/api/v1/watchlist/{id}
```

---

## Sync (Replace) Contracts 同步（覆蓋）合約

Replaces all contracts in the watchlist with the provided list.
以提供的清單覆蓋自選股中的所有合約。

### Python Usage Python 用法

```python
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

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `group_id` | `str` | (required) | Watchlist ID 清單 ID |
| `contracts` | `List[BaseContract]` | (required) | Contracts to sync (replaces all) 要同步的合約 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X PUT http://localhost:8080/api/v1/watchlist/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2330"},
      {"security_type": "STK", "exchange": "TSE", "code": "2454"}
    ]
  }'
```

---

## Add Contracts 新增合約

### Python Usage Python 用法

```python
updated = api.watchlist_add_contract(
    group_id="watchlist_id",
    contracts=[
        api.Contracts.Stocks["2454"],
        api.Contracts.Futures.TXF.TXFR1,
    ]
)
print(f"Updated contracts: {len(updated.contracts)}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `group_id` | `str` | (required) | Watchlist ID 清單 ID |
| `contracts` | `List[BaseContract]` | (required) | Contracts to add 要新增的合約 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/watchlist/{id}/contracts \
  -H "Content-Type: application/json" \
  -d '{
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2454"}
    ]
  }'
```

---

## Remove Contracts 移除合約

### Python Usage Python 用法

```python
updated = api.watchlist_delete_contract(
    group_id="watchlist_id",
    contracts=[api.Contracts.Stocks["2454"]]
)
print(f"Remaining contracts: {len(updated.contracts)}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `group_id` | `str` | (required) | Watchlist ID 清單 ID |
| `contracts` | `List[BaseContract]` | (required) | Contracts to remove 要移除的合約 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |
| `cb` | `Callable` | `None` | Callback 回呼函數 |

### HTTP Example HTTP 範例

```bash
curl -X DELETE http://localhost:8080/api/v1/watchlist/{id}/contracts \
  -H "Content-Type: application/json" \
  -d '{
    "contracts": [
      {"security_type": "STK", "exchange": "TSE", "code": "2454"}
    ]
  }'
```

---

## Watchlist Attributes 自選股屬性

### Watchlist Object 自選股物件

```python
watchlist.id          # str: Watchlist ID 清單 ID
watchlist.person_id   # str: Owner user ID 擁有者 ID
watchlist.name        # str: Watchlist name 清單名稱
watchlist.contracts   # list: List of BaseContract objects 合約列表
```

### Contract in Watchlist 清單中的合約

```python
contract.security_type  # SecurityType: STK/FUT/OPT/IDX 商品類型
contract.exchange       # Exchange: TSE/OTC/TAIFEX 交易所
contract.code           # str: Contract code 合約代碼
```

---

## HTTP Endpoint Summary HTTP 端點一覽

All watchlist endpoints are under `/api/v1/watchlist`:
所有自選股端點位於 `/api/v1/watchlist`：

| Method 方法 | Path 路徑 | Description 說明 |
|------------|-----------|------------------|
| `GET` | `/watchlist` | List all watchlists 取得所有清單 |
| `POST` | `/watchlist` | Create watchlist 建立清單 |
| `GET` | `/watchlist/{id}` | Get watchlist by ID 依 ID 取得清單 |
| `PUT` | `/watchlist/{id}` | Sync (replace) contracts 同步合約 |
| `DELETE` | `/watchlist/{id}` | Delete watchlist 刪除清單 |
| `POST` | `/watchlist/{id}/contracts` | Add contracts 新增合約 |
| `DELETE` | `/watchlist/{id}/contracts` | Remove contracts 移除合約 |

See [HTTP_API.md](HTTP_API.md) for full endpoint details.

---

## Reference 參考資料

- Original shioaji docs 原版文檔: https://sinotrade.github.io/
