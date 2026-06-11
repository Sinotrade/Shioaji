# Watchlist 自選股清單

This document covers watchlist CRUD operations in Shioaji.
本文件說明 Shioaji 中自選股清單的增刪改查功能。

See [HTTP_API.md](HTTP_API.md) for full endpoint details. This file owns `Watchlist` / `Vec<Watchlist>` response shapes.

Watchlist is supplemental HTTP functionality, not part of the main tutorial flow.

Python methods return `Watchlist` objects or `list[Watchlist]` with Python contract objects. HTTP clients receive JSON `Watchlist` / `Vec<Watchlist>` shapes; fetch `/openapi.json` only when exact installed-server fields are required.
Python method 回傳的是包含 Python contract 物件的 `Watchlist` 或 `list[Watchlist]`。HTTP client 收到的是 JSON `Watchlist` / `Vec<Watchlist>` shape；只有需要確認安裝版本精確欄位時才查 `/openapi.json`。

CLI watchlist commands are available via `shioaji watchlist <SUBCOMMAND>`; see [CLI.md](CLI.md) for full flag tables.
CLI 自選股命令可透過 `shioaji watchlist <SUBCOMMAND>` 使用；完整旗標說明見 [CLI.md](CLI.md)。

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Watchlist Response and Decision Summary 自選股回應與決策摘要](#watchlist-response-and-decision-summary-自選股回應與決策摘要)
- [Fetch All Watchlists 取得所有清單](#fetch-all-watchlists-取得所有清單)
- [Get Watchlist by ID 依 ID 取得清單](#get-watchlist-by-id-依-id-取得清單)
- [Create Watchlist 建立清單](#create-watchlist-建立清單)
- [Delete Watchlist 刪除清單](#delete-watchlist-刪除清單)
- [Sync (Replace) Contracts 同步（覆蓋）合約](#sync-replace-contracts-同步覆蓋合約)
- [Add Contracts 新增合約](#add-contracts-新增合約)
- [Remove Contracts 移除合約](#remove-contracts-移除合約)
- [Watchlist Attributes 自選股屬性](#watchlist-attributes-自選股屬性)
- [HTTP Endpoint Summary HTTP 端點一覽](#http-endpoint-summary-http-端點一覽)
- [Apps Supplemental Endpoints 自訂應用補充端點](#apps-supplemental-endpoints-自訂應用補充端點)

---

## Overview 概覽

| Python Method 方法 | Description 說明 | HTTP Method + Path | CLI Command 指令 |
|---------------------|------------------|--------------------|------------------|
| `fetch_watchlists()` | Get all watchlists 取得所有清單 | `GET /api/v1/watchlist` | `shioaji watchlist list` |
| `get_watchlist(group_id)` | Get one watchlist 取得單個清單 | `GET /api/v1/watchlist/{id}` | `shioaji watchlist show --id <ID>` |
| `create_watchlist(name, contracts)` | Create new watchlist 建立清單 | `POST /api/v1/watchlist` | `shioaji watchlist create --name <NAME> [--codes <CODES>]` |
| `delete_watchlist(group_id)` | Delete watchlist 刪除清單 | `DELETE /api/v1/watchlist/{id}` | `shioaji watchlist delete --id <ID>` |
| `sync_watchlist(group_id, contracts)` | Replace all contracts 覆蓋所有合約 | `PUT /api/v1/watchlist/{id}` | `shioaji watchlist sync --id <ID> --codes <CODES>` |
| `watchlist_add_contract(group_id, contracts)` | Add contracts 新增合約 | `POST /api/v1/watchlist/{id}/contracts` | `shioaji watchlist add --id <ID> --codes <CODES>` |
| `watchlist_delete_contract(group_id, contracts)` | Remove contracts 移除合約 | `DELETE /api/v1/watchlist/{id}/contracts` | `shioaji watchlist remove --id <ID> --codes <CODES>` |

---

## Watchlist Response and Decision Summary 自選股回應與決策摘要

Watchlist is supplemental. Prefer normal market-data/order references for trading workflows; use this file when the user explicitly asks to manage saved watchlists or uploaded apps.
Watchlist 屬於補充功能。交易流程優先看行情/下單 reference；只有使用者明確要管理自選股或上傳應用時才用本檔。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| List watchlists | `api.fetch_watchlists()` -> `list[Watchlist]` | `GET /api/v1/watchlist` -> `Vec<Watchlist>` | `shioaji watchlist list` -> `Vec<Watchlist>` (toon/json) | Empty list means no saved watchlists; do not treat it as auth failure unless other protected endpoints also fail. |
| Get watchlist | `api.get_watchlist(group_id)` -> `Watchlist` | `GET /api/v1/watchlist/{id}` -> `Watchlist` | `shioaji watchlist show --id <ID>` -> `Watchlist` | 404/error means the id does not exist or is not visible to this account; do not invent a fallback id. |
| Create watchlist | `api.create_watchlist(name, contracts=None)` -> `Watchlist` | `POST /api/v1/watchlist` -> `Watchlist` | `shioaji watchlist create --name <NAME> [--codes <CODES>]` -> `Watchlist` | Response contains the created `id`, `name`, and normalized `contracts`; store/use the returned `id`, not the submitted name. |
| Delete watchlist | `api.delete_watchlist(group_id)` -> deleted `Watchlist` | `DELETE /api/v1/watchlist/{id}` -> deleted `Watchlist` | `shioaji watchlist delete --id <ID>` -> deleted `Watchlist` | Successful response is the deleted list object. If follow-up list still shows it, refresh before retrying destructive operations. |
| Sync contracts | `api.sync_watchlist(group_id, contracts)` -> `Watchlist` | `PUT /api/v1/watchlist/{id}` -> `Watchlist` | `shioaji watchlist sync --id <ID> --codes <CODES>` -> `Watchlist` | This replaces all contracts. Use only when the user intends overwrite; for append/remove use add/delete contract endpoints. |
| Add contracts | `api.watchlist_add_contract(group_id, contracts)` -> `Watchlist` | `POST /api/v1/watchlist/{id}/contracts` -> `Watchlist` | `shioaji watchlist add --id <ID> --codes <CODES>` -> `Watchlist` | Response is the updated list. Check returned `contracts` to confirm which contracts were accepted/normalized. |
| Remove contracts | `api.watchlist_delete_contract(group_id, contracts)` -> `Watchlist` | `DELETE /api/v1/watchlist/{id}/contracts` -> `Watchlist` | `shioaji watchlist remove --id <ID> --codes <CODES>` -> `Watchlist` | Response is the updated list. If the contract is still present, check code/security_type/exchange normalization before retrying. |

CLI `--codes` accepts comma-separated codes; each code is resolved through the contract lookup endpoint so exchange and `target_code` are filled automatically. With `--security-type STK` (the default) the lookup falls back to FUT/OPT/IND when no stock matches; `FUT`, `OPT`, or `IND` searches only that type.
CLI 的 `--codes` 接受逗號分隔的代碼；每個代碼會經由合約查詢端點解析，自動帶入交易所與 `target_code`。`--security-type STK`（預設值）查無股票時會回退嘗試 FUT/OPT/IND；指定 `FUT`、`OPT`、`IND` 則只查該類型。

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

### CLI Example CLI 範例

```bash
shioaji watchlist list
shioaji watchlist list -f json
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

### CLI Example CLI 範例

```bash
shioaji watchlist show --id watchlist_id
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

### CLI Example CLI 範例

```bash
# Create with contracts 建立並加入合約
shioaji watchlist create --name "My Watchlist" --codes 2330,2317

# Create empty watchlist 建立空白清單
shioaji watchlist create --name "Empty List"

# Futures contracts 期貨合約
shioaji watchlist create --name "Futures" --codes TXFR1 --security-type FUT
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

### CLI Example CLI 範例

```bash
shioaji watchlist delete --id watchlist_id
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

### CLI Example CLI 範例

```bash
# Replaces ALL contracts in the watchlist 覆蓋清單中的所有合約
shioaji watchlist sync --id watchlist_id --codes 2330,2454
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

### CLI Example CLI 範例

```bash
shioaji watchlist add --id watchlist_id --codes 2454
shioaji watchlist add --id watchlist_id --codes TXFR1 --security-type FUT
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

### CLI Example CLI 範例

```bash
shioaji watchlist remove --id watchlist_id --codes 2454
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
contract.security_type  # SecurityType: STK/FUT/OPT/IND 商品類型
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

See [HTTP_API.md](HTTP_API.md) for full endpoint details. Agent decision guidance is in the sections above.

---

## Apps Supplemental Endpoints 自訂應用補充端點

Apps are HTTP-only supplemental endpoints for uploaded web app files. They are not Python trading APIs and have no primary CLI commands.
Apps 是 HTTP-only 的補充端點，用於上傳網頁應用檔案；不是 Python 交易 API，也沒有主要 CLI command。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| List apps | No Python API | `GET /api/v1/apps` -> `{ apps: Vec<String> }` | No primary CLI command | Empty `apps` means no uploaded apps. This does not affect trading API health. |
| Upload app | No Python API | `POST /api/v1/apps/{name}` multipart field `files` -> `{ name: String, files: Vec<String> }` | No primary CLI command | Use multipart field name `files`; total upload limit is 50 MB; chunked uploads are rejected because `Content-Length` is required. |
| Delete app | No Python API | `DELETE /api/v1/apps/{name}` -> `{ deleted: String }` | No primary CLI command | Response confirms the app name removed. 404/error means not found or invalid name/path. |
| Serve app | No Python API | `GET /apps/{path}` serves uploaded files, outside `/api/v1` | No primary CLI command | Public serving route. Do not send bearer auth assumptions into static app fetches; path traversal is rejected. |
