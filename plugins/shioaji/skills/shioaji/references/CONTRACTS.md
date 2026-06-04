# Contracts 合約

This document covers how to access and use contract objects in Shioaji.
本文件說明如何在 Shioaji 中存取和使用合約物件。

This file owns `ContractRecord`, contract query response shapes, and continuous futures `target_code` decisions.

---

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Contracts Response and Decision Summary 商品檔回應與決策摘要](#contracts-response-and-decision-summary-商品檔回應與決策摘要)
- [Stock Contracts 股票合約](#stock-contracts-股票合約)
- [Futures Contracts 期貨合約](#futures-contracts-期貨合約)
- [Options Contracts 選擇權合約](#options-contracts-選擇權合約)
- [Index Contracts 指數合約](#index-contracts-指數合約)
- [Fetching All Contracts 取得所有合約](#fetching-all-contracts-取得所有合約)
- [Contract Update 合約更新](#contract-update-合約更新)

---

## Overview 概覽

Contracts are fetched during login, but sync login defaults to background loading (`contracts_timeout=0`). If code must use `api.Contracts` immediately after login, wait for loading with `contracts_timeout`, observe progress with `contracts_cb`, or check `api.Contracts.status`.
商品檔會在登入時下載，但同步 login 預設是背景載入（`contracts_timeout=0`）。如果程式登入後要立刻使用 `api.Contracts`，請用 `contracts_timeout` 等待、用 `contracts_cb` 觀察進度，或檢查 `api.Contracts.status`。

```python
import shioaji as sj

api = sj.Shioaji()
api.login(
    api_key="YOUR_KEY",
    secret_key="YOUR_SECRET",
    contracts_timeout=10000,  # Wait up to 10 seconds for contracts
)

# Contracts are now available 合約已可使用
```

---

## Contracts Response and Decision Summary 商品檔回應與決策摘要

Use this table before generating code that resolves contracts. Python uses loaded contract objects; HTTP and other languages use `ContractRecord` JSON.
產生商品檔查詢程式前先看這張表。Python 使用已載入的 contract object；HTTP 與其他語言使用 `ContractRecord` JSON。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| Use loaded contracts | `api.Contracts.Stocks[...]`, `api.Contracts.Futures[...]`, `api.Contracts.Options[...]`, `api.Contracts.Indexs[...]` return Python contract objects | No direct equivalent | No dedicated contract lookup command | If code needs contracts immediately after sync login, set `contracts_timeout > 0`, use `contracts_cb`, or check `api.Contracts.status`; otherwise background loading can race. |
| Fetch/update contracts | `api.fetch_contracts(contract_download=True)` updates `api.Contracts`; sync/async can use `contracts_cb` on this method | No HTTP update endpoint | No dedicated contract update command | Use for Python code that needs a refresh or progress notification. Do not suggest it for HTTP-only clients. |
| Contract loading callback | Sync `login(..., contracts_cb=...)`; `callback()` after all types or `callback(security_type)` per type. `api.fetch_contracts(..., contracts_cb=...)` uses per-type callback | No HTTP/SSE callback | No CLI callback | `contracts_cb` is Python-only and plural. It notifies download/loading progress, not runtime upstream update events. |
| Runtime contract update event | `api.set_contract_event_callback(callback)` for Python `SYS/CONTRACT` updates after login | No HTTP/SSE callback | No CLI callback | Different from `contracts_cb`. Use only when Python code must react to upstream contract update events after startup. |
| Query contracts | Python usually iterates `api.Contracts.*`; no Python wrapper for the HTTP pagination shape | `POST /api/v1/data/contracts` -> `ContractsQueryResponse { contracts, security_type, page, page_size, max_page, total }` | No dedicated contract lookup command | Empty `contracts` means no records for that filter/page. If the server returns `Contracts not loaded`, wait/retry or restart after contract loading finishes. Use `page=-1` only when the caller truly needs all records. |
| Look up single contract | Python uses contract tree lookup by code/symbol | `GET /api/v1/data/contracts/{code}?security_type=...` -> `ContractRecord` | No dedicated contract lookup command | `security_type` is required. 404 means no matching code under that type; do not silently change security type unless the user asked for fuzzy search. |
| Continuous futures R1/R2 | Python contract object carries `target_code` and normal order/stream helpers can use the object | `ContractRecord.target_code` is populated for aliases such as `TXFR1`/`TXFR2` | CLI stream/order resolves the contract and forwards `target_code` where needed | HTTP/SSE clients must copy `target_code` into stream subscribe for `TXFR1`/`TXFR2`; regular futures do not need it. Missing `target_code` can produce heartbeat-only SSE. |

`ContractRecord` is the HTTP/server JSON contract shape. Important fields include `security_type`, `exchange`, `code`, `symbol`, `name`, prices/limits, `update_date`, and `target_code`.
`ContractRecord` 是 HTTP/server JSON 的商品檔形狀。重要欄位包含 `security_type`、`exchange`、`code`、`symbol`、`name`、價格/漲跌停、`update_date` 與 `target_code`。

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
contract.target_code    # Usually empty; only continuous futures aliases use it
```

### HTTP: Look Up a Contract 透過 HTTP 查詢合約

```bash
# GET /api/v1/data/contracts/<code>?security_type=STK
curl "http://localhost:8080/api/v1/data/contracts/2330?security_type=STK"
```

Response:
```json
{
  "code": "2330",
  "symbol": "TSE2330",
  "name": "台積電",
  "exchange": "TSE",
  "security_type": "STK",
  "limit_up": 620.0,
  "limit_down": 508.0,
  "reference": 564.0,
  "update_date": "2026-03-31",
  "day_trade": "Yes",
  "target_code": ""
}
```

### HTTP: Query Contracts with Pagination 分頁查詢合約

```bash
# POST /api/v1/data/contracts
curl -X POST http://localhost:8080/api/v1/data/contracts \
  -H "Content-Type: application/json" \
  -d '{"security_type": "STK", "page": 1, "page_size": 50}'
```

Response:
```json
{
  "contracts": [ ... ],
  "security_type": "STK",
  "page": 1,
  "page_size": 50,
  "max_page": 40,
  "total": 1987
}
```

Use `"page": -1` to return all records (no pagination).
使用 `"page": -1` 回傳所有記錄（不分頁）。

---

## Futures Contracts 期貨合約

### Access Futures 存取期貨

```python
# By futures code 以期貨代碼
tx = api.Contracts.Futures["TXF"]     # Taiwan Index Futures 台指期
mtx = api.Contracts.Futures["MXF"]    # Mini Taiwan Index Futures 小台指

# Current month contract 當月合約
txf_current = api.Contracts.Futures["TXFC0"]  # C0 = current month 近月

# Specific month 指定月份
txf_202401 = api.Contracts.Futures["TXF202401"]
```

### HTTP: Look Up a Futures Contract

```bash
curl "http://localhost:8080/api/v1/data/contracts/TXFC0?security_type=FUT"
```

For continuous-month aliases such as `TXFR1` and `TXFR2`, the response carries `target_code`, the resolved real contract code. Python and CLI can usually use the contract object or symbol directly. HTTP and other languages must copy `target_code` when subscribing to streaming data for `TXFR1`/`TXFR2`; regular futures contracts do not need this.

```bash
curl "http://localhost:8080/api/v1/data/contracts/TXFR1?security_type=FUT"
# response includes: "code":"TXFR1", "target_code":"TXFF6"
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
contract.target_code    # Only continuous-month aliases such as TXFR1/TXFR2
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

### HTTP: Look Up an Options Contract

```bash
curl "http://localhost:8080/api/v1/data/contracts/TXO202401C18000?security_type=OPT"
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

### HTTP: Look Up an Index Contract

```bash
curl "http://localhost:8080/api/v1/data/contracts/TSE001?security_type=IND"
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

### HTTP: Query by Security Type

```bash
# All futures 所有期貨
curl -X POST http://localhost:8080/api/v1/data/contracts \
  -H "Content-Type: application/json" \
  -d '{"security_type": "FUT", "page": -1}'

# All options 所有選擇權
curl -X POST http://localhost:8080/api/v1/data/contracts \
  -H "Content-Type: application/json" \
  -d '{"security_type": "OPT", "page": 1, "page_size": 100}'
```

**Security type values 合約類型值:** `STK` (stocks), `FUT` (futures), `OPT` (options), `IND` (index).

---

## Contract Update 合約更新

Contracts can be updated manually if needed:
如需要可手動更新合約：

```python
# Fetch latest contract info 取得最新合約資訊
api.fetch_contracts(contract_download=True)

# With callback to track progress 附回調追蹤進度
api.fetch_contracts(contract_download=True, contracts_cb=lambda st: print(f"Loaded: {st}"))
```

### Contract Loading Callbacks 商品檔下載通知

Use `contracts_cb` when users need to control flow or notify another system that contract files are ready. The parameter name is `contracts_cb` (plural), not `contract_cb`.

```python
from shioaji import SecurityType

def on_contract_type_done(security_type: SecurityType):
    print(f"{security_type} contracts loaded")

api.login(
    api_key="YOUR_KEY",
    secret_key="YOUR_SECRET",
    contracts_timeout=10000,      # Block up to 10 seconds while loading contracts
    contracts_cb=on_contract_type_done,
)
```

Sync `login(..., contracts_cb=...)` accepts either `callback()` (called once after all contract types finish) or `callback(security_type)` (called after each contract type finishes). The `security_type` argument is a Python `SecurityType` enum such as `SecurityType.Stock`, not the raw string `"STK"`.

`api.fetch_contracts(..., contracts_cb=...)` uses the per-type callback form and works for both sync and async clients. Async `login(...)` does not accept `contracts_cb`; use `await api.fetch_contracts(..., contracts_cb=...)` after login when async code needs progress notification.

`contracts_cb` is Python-only. The CLI/server does not expose an equivalent callback, environment variable, HTTP endpoint, or SSE event for contract-loading completion. For server/HTTP clients, use contract lookup as a readiness check:

```bash
curl "http://localhost:8080/api/v1/data/contracts/2330?security_type=STK"
```

If contracts are not loaded yet, the server returns an error such as `Contracts not loaded`. In that case, retry with backoff or check the server startup logs; do not suggest `contracts_cb` for HTTP clients.

Runtime contract update events are separate from `contracts_cb`. Use `api.set_contract_event_callback(...)` only when Python code needs to react to upstream `SYS/CONTRACT` updates after login. HTTP/server clients do not expose an equivalent contract-update callback or SSE channel.
執行中的商品檔更新事件和 `contracts_cb` 不同。Python 程式若需要在登入後監聽上游 `SYS/CONTRACT` 更新，可使用 `api.set_contract_event_callback(...)`。HTTP/server client 沒有對應的商品檔更新 callback 或 SSE channel。

### Async 非同步

```python
api = sj.ShioajiAsync()
await api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")
contracts = await api.fetch_contracts(contract_download=True)
```

---

**Note 注意:** There is no CLI command for contract lookup. Use Python or HTTP API.
目前沒有合約查詢的 CLI 命令，請使用 Python 或 HTTP API。

For full HTTP endpoint inventory, see [HTTP_API.md](HTTP_API.md).
完整的 HTTP 端點清單請參見 [HTTP_API.md](HTTP_API.md)。
