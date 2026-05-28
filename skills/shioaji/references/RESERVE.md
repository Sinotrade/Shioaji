# Reserve Orders 預收券款

This document covers reserve stock and earmarking operations in Shioaji.
本文件說明 Shioaji 中的預收券款及預收款項功能。

See [HTTP_API.md](HTTP_API.md) for full endpoint details. This file owns reserve response payload shapes.

Python returns reserve wrapper responses with `.response` and `.error`; HTTP returns the inner reserve object directly. Check the returned `status` and `info` before assuming the reserve operation succeeded. Fetch `/openapi.json` only when exact installed-server fields are required.
Python 回傳帶有 `.response` 與 `.error` 的預收 wrapper response；HTTP 直接回傳內層預收物件。請先檢查回傳 `status` 與 `info` 後再判斷預收是否成功。只有需要確認安裝版本精確欄位時才查 `/openapi.json`。

For stocks under disposition, attention, or warning status, you must reserve shares/funds before trading.
處置股、注意股或警示股在交易前須預收券款。

Service hours: 8:00 - 14:30 on trading days.
服務時間：交易日 8:00 至 14:30。

## Table of Contents 目錄

- [Overview 概覽](#overview-概覽)
- [Reserve Response and Decision Summary 預收回應與決策摘要](#reserve-response-and-decision-summary-預收回應與決策摘要)
- [Stock Reserve Summary 預收券款摘要](#stock-reserve-summary-預收券款摘要)
- [Stock Reserve Detail 預收券款明細](#stock-reserve-detail-預收券款明細)
- [Reserve Stock 預收股票](#reserve-stock-預收股票)
- [Earmarking Detail 預收款項明細](#earmarking-detail-預收款項明細)
- [Reserve Earmarking 預收款項](#reserve-earmarking-預收款項)
- [HTTP Endpoint Summary HTTP 端點一覽](#http-endpoint-summary-http-端點一覽)

---

## Overview 概覽

All reserve endpoints are under the **order** domain (not portfolio).
所有預收端點屬於 **order** 網域（非 portfolio）。

| Python Method 方法 | Description 說明 | HTTP Path |
|---------------------|------------------|-----------|
| `stock_reserve_summary()` | Reserve summary 預收摘要 | `POST /api/v1/order/stock_reserve_summary` |
| `stock_reserve_detail()` | Reserve detail 預收明細 | `POST /api/v1/order/stock_reserve_detail` |
| `reserve_stock()` | Reserve shares 預收股票 | `POST /api/v1/order/reserve_stock` |
| `earmarking_detail()` | Earmarking detail 預收款項明細 | `POST /api/v1/order/earmarking_detail` |
| `reserve_earmarking()` | Reserve earmarking 預收款項 | `POST /api/v1/order/reserve_earmarking` |

---

## Reserve Response and Decision Summary 預收回應與決策摘要

Reserve APIs are stock-account operations. They require a signed stock account in production and return empty/default values in simulation.
預收 API 是股票帳戶操作。正式環境需要已簽署的股票帳戶；模擬環境會回傳空或預設值。

| Operation | Python return | HTTP response | CLI output | Agent decision |
|-----------|---------------|---------------|------------|----------------|
| Stock reserve summary | `api.stock_reserve_summary(account)` -> `ReserveStocksSummaryResponse`; read `resp.response.stocks` | `POST /api/v1/order/stock_reserve_summary` -> `ReserveStocksSummary { stocks, account }` | No primary CLI command | Empty `stocks` can mean no reserve-eligible stocks or simulation mode. Use `available_share` to decide how much can be reserved; do not reserve more than available. |
| Stock reserve detail | `api.stock_reserve_detail(account)` -> `ReserveStocksDetailResponse`; read `resp.response.stocks` | `POST /api/v1/order/stock_reserve_detail` -> `ReserveStocksDetail { stocks, account }` | No primary CLI command | Each stock row has `status` and `info`; use them to explain accepted/rejected reserve records. Empty list can be normal. |
| Reserve stock | `api.reserve_stock(contract, share, account=...)` -> `ReserveStockResponse`; read `resp.response.status` / `resp.response.info` | `POST /api/v1/order/reserve_stock` -> `ReserveOrderResp { contract, account, share, status, info }` | No primary CLI command | `status=true` is the success signal. If `status=false`, read `info`; in simulation, `status=false` with empty `info` is the default no-op response. |
| Earmarking detail | `api.earmarking_detail(account)` -> `EarmarkStocksDetailResponse`; read `resp.response.stocks` | `POST /api/v1/order/earmarking_detail` -> `EarmarkStocksDetail { stocks, account }` | No primary CLI command | Each row includes `share`, `price`, `amount`, `status`, and `info`; use row-level `status/info`, not HTTP 200 alone. |
| Reserve earmarking | `api.reserve_earmarking(contract, share, price, account=...)` -> `ReserveEarmarkingResponse`; read `resp.response.status` / `resp.response.info` | `POST /api/v1/order/reserve_earmarking` -> `EarmarkingOrderResp { contract, account, share, price, status, info }` | No primary CLI command | `status=true` is the success signal. If `status=false`, read `info`; simulation returns default `status=false`. |

Do not treat HTTP 200 alone as reserve success. These endpoints can return a valid response object whose `status` is false.
不要只用 HTTP 200 判斷預收成功。這些端點可能回傳合法 response object，但其中 `status` 是 false。

---

## Stock Reserve Summary 預收券款摘要

Query which stocks are available for reserve and how many shares are already reserved.
查詢哪些股票可預收以及已預收股數。

### Python Usage Python 用法

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Get reserve summary 取得預收券款摘要
summary = api.stock_reserve_summary(api.stock_account)

for stock in summary.response.stocks:
    print(f"Code: {stock.contract.code}")
    print(f"Available: {stock.available_share}")
    print(f"Reserved: {stock.reserved_share}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | (required) | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/order/stock_reserve_summary \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Stock Reserve Detail 預收券款明細

Query details of already-reserved stocks.
查詢已預收股票的明細。

### Python Usage Python 用法

```python
detail = api.stock_reserve_detail(api.stock_account)

for stock in detail.response.stocks:
    print(f"Code: {stock.contract.code}")
    print(f"Share: {stock.share}")
    print(f"Status: {stock.status}")
    print(f"Info: {stock.info}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | (required) | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/order/stock_reserve_detail \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Reserve Stock 預收股票

Reserve a specific number of shares for a disposition stock.
預收特定股數的處置股。

### Python Usage Python 用法

```python
contract = api.Contracts.Stocks["2890"]

# Reserve 1000 shares 預收 1000 股
resp = api.reserve_stock(contract, 1000, account=api.stock_account)

print(f"Status: {resp.response.status}")
print(f"Share: {resp.response.share}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `contract` | `Contract` | (required) | Stock contract 股票合約 |
| `share` | `int` | (required) | Number of shares to reserve 預收股數 |
| `account` | `Account` | stock account | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/order/reserve_stock \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "your_account_id",
    "contract": {
      "security_type": "STK",
      "exchange": "TSE",
      "code": "2890"
    },
    "share": 1000
  }'
```

---

## Earmarking Detail 預收款項明細

Query details of earmarking (cash pre-payment) records.
查詢預收款項（現金預付）記錄明細。

### Python Usage Python 用法

```python
detail = api.earmarking_detail(api.stock_account)

for stock in detail.response.stocks:
    print(f"Code: {stock.contract.code}")
    print(f"Share: {stock.share}")
    print(f"Price: {stock.price}")
    print(f"Amount: {stock.amount}")
    print(f"Status: {stock.status}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `account` | `Account` | (required) | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/order/earmarking_detail \
  -H "Content-Type: application/json" \
  -d '{"account_id": "your_account_id"}'
```

---

## Reserve Earmarking 預收款項

Pre-pay cash when buying disposition stocks.
買進處置股時預付現金款項。

### Python Usage Python 用法

```python
contract = api.Contracts.Stocks["2890"]

# Reserve with price 預收並指定價格
resp = api.reserve_earmarking(contract, 1000, 15.15, account=api.stock_account)

print(f"Price: {resp.response.price}")
print(f"Status: {resp.response.status}")
```

### Parameters 參數

| Parameter 參數 | Type 類型 | Default | Description 說明 |
|---------------|----------|---------|------------------|
| `contract` | `Contract` | (required) | Stock contract 股票合約 |
| `share` | `int` | (required) | Number of shares 預收股數 |
| `price` | `float` | (required) | Price per share 每股價格 |
| `account` | `Account` | stock account | Stock account 股票帳戶 |
| `timeout` | `int` | `5000` | Timeout ms 超時毫秒 |

### HTTP Example HTTP 範例

```bash
curl -X POST http://localhost:8080/api/v1/order/reserve_earmarking \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "your_account_id",
    "contract": {
      "security_type": "STK",
      "exchange": "TSE",
      "code": "2890"
    },
    "share": 1000,
    "price": 15.15
  }'
```

---

## Reserve All Available 全部預收

Common pattern: reserve all available shares for all disposition stocks.
常見模式：預收所有處置股的所有可用股數。

```python
summary = api.stock_reserve_summary(api.stock_account)

for stock in summary.response.stocks:
    if stock.available_share > 0:
        resp = api.reserve_stock(
            stock.contract,
            stock.available_share,
            account=api.stock_account,
        )
        print(f"Reserved {stock.contract.code}: {resp.response.status}")
```

---

## HTTP Endpoint Summary HTTP 端點一覽

All reserve endpoints use `POST` method under `/api/v1/order/`:
所有預收端點使用 `POST` 方法，路徑為 `/api/v1/order/`：

| Path 路徑 | Description 說明 |
|-----------|------------------|
| `/order/stock_reserve_summary` | Reserve summary 預收摘要 |
| `/order/stock_reserve_detail` | Reserve detail 預收明細 |
| `/order/reserve_stock` | Reserve shares 預收股票 |
| `/order/earmarking_detail` | Earmarking detail 預收款項明細 |
| `/order/reserve_earmarking` | Reserve earmarking 預收款項 |

See [HTTP_API.md](HTTP_API.md) for full endpoint details. Reserve response wrappers and simulation defaults are described above in this file.
