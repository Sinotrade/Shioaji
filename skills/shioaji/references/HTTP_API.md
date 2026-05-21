# Shioaji HTTP API Reference / Shioaji HTTP API 參考

> **Shioaji is no longer Python-only.** The Rust reimplementation exposes a full HTTP API server,
> enabling any language, tool, or platform to trade Taiwan markets. The same binary that powers
> the CLI also serves a RESTful API with real-time SSE streaming, OpenAPI documentation, a
> built-in dashboard, and support for custom embedded applications.

> Canonical inventory of every HTTP endpoint, generated from source.
> Source of truth: `src/server/http/mod.rs`, `src/server/http/*.rs`

---

## Table of Contents / 目錄

1. [Overview / 概覽](#overview--概覽)
2. [Authentication / 認證](#authentication--認證)
3. [Server Configuration / 伺服器設定](#server-configuration--伺服器設定)
4. [UDS Support / Unix Domain Socket 支援](#uds-support--unix-domain-socket-支援)
5. [Complete Endpoint Table / 完整端點列表](#complete-endpoint-table--完整端點列表)
   - [Health & Info / 健康檢查與資訊](#health--info--健康檢查與資訊)
   - [Auth / 認證端點](#auth--認證端點)
   - [Data / 行情資料](#data--行情資料)
   - [Order / 委託](#order--委託)
   - [Portfolio / 投資組合](#portfolio--投資組合)
   - [Stream / 即時串流](#stream--即時串流)
   - [Watchlist / 自選清單](#watchlist--自選清單)
   - [Apps / 自訂應用](#apps--自訂應用)
6. [Endpoint Details / 端點詳情](#endpoint-details--端點詳情)
   - [Health & Info](#health--info)
   - [Auth Endpoints](#auth-endpoints)
   - [Data Endpoints](#data-endpoints)
   - [Order Endpoints](#order-endpoints)
   - [Portfolio Endpoints](#portfolio-endpoints)
   - [Stream Endpoints (SSE)](#stream-endpoints-sse)
   - [Watchlist Endpoints](#watchlist-endpoints)
   - [Apps Endpoints](#apps-endpoints)
7. [OpenAPI Documentation / OpenAPI 文件](#openapi-documentation--openapi-文件)
8. [Dashboard / 儀表板](#dashboard--儀表板)
9. [Custom App Embedding / 自訂應用嵌入](#custom-app-embedding--自訂應用嵌入)
10. [Middleware Stack / 中介層堆疊](#middleware-stack--中介層堆疊)
11. [Error Responses / 錯誤回應](#error-responses--錯誤回應)

---

## Overview / 概覽

The Shioaji HTTP API is served by the same `shioaji` binary via `shioaji server start`. It is built on the Salvo web framework and provides:

- RESTful JSON endpoints for all trading operations
- Server-Sent Events (SSE) for real-time market data and order events
- OpenAPI 3.0 specification with Scalar documentation UI
- Built-in React dashboard (embedded at build time)
- Custom app hosting (upload your own web apps)
- CORS support, gzip compression, request logging, panic recovery

**Base URL**: `http://127.0.0.1:8080` (default)
**API prefix**: `/api/v1/`

---

## Authentication / 認證

Authentication uses **Bearer token** format with the SJ_API_KEY and SJ_SEC_KEY:

```
Authorization: Bearer <SJ_API_KEY>:<SJ_SEC_KEY>
```

### When is auth required? / 何時需要認證?

- **Localhost** (`127.0.0.1`, `::1`): Authentication is **disabled**. All endpoints are accessible without credentials.
- **Non-localhost** (any other bind address): Authentication is **required** on all protected endpoints. The `/api/v1/health` and `/api/v1/info` endpoints remain public.

### Constant-time comparison / 常數時間比對

Credential validation uses `subtle::ConstantTimeEq` for timing-attack resistance. Both API key and secret key are validated together.

### Example / 範例

```bash
# Localhost -- no auth needed
curl http://127.0.0.1:8080/api/v1/auth/accounts

# Remote -- auth required
curl -H "Authorization: Bearer YOUR_API_KEY:YOUR_SECRET_KEY" \
     http://192.168.1.100:8080/api/v1/auth/accounts
```

---

## Server Configuration / 伺服器設定

Configure the server via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SJ_API_KEY` | (required) | API key for Shioaji authentication |
| `SJ_SEC_KEY` | (required) | Secret key for Shioaji authentication |
| `SJ_PRODUCTION` | `false` | Enable production mode (default: simulation) |
| `SJ_HTTP_ADDR` | `127.0.0.1:8080` | Server bind address (also: `SJ_BIND_ADDR`, `BIND_ADDR`) |
| `SJ_HTTP_CORS` | `true` | Enable CORS |
| `SJ_HTTP_TIMEOUT` | `30` | HTTP request timeout in seconds |
| `SJ_HTTP_LOG` | `true` | Enable HTTP request logging |
| `SJ_PROXY` | (none) | HTTP proxy URL for upstream Shioaji connections |
| `SJ_CA_PATH` | (none) | Path to CA certificate file |
| `SJ_CA_PASSWD` | (none) | CA certificate password |
| `SJ_HOME_PATH` | `~/.shioaji` | Custom home directory for token pool, contracts, cache |
| `SJ_TIMEOUT` | `60000` | Solace request-reply timeout in milliseconds |

### UDS-specific variables / UDS 專用變數

| Variable | Default | Description |
|----------|---------|-------------|
| `SJ_UDS_PATH` | `~/.shioaji/sessions/server-{port}.sock` | Custom Unix domain socket path |
| `SJ_UDS_DISABLE` | `false` | Disable UDS transport |

---

## UDS Support / Unix Domain Socket 支援

On Unix systems, the server binds to both TCP and a Unix domain socket simultaneously.

- **Default path**: `~/.shioaji/sessions/server-{port}.sock`
- **Permissions**: `0600` (owner-only read/write)
- **Stale detection**: Existing sockets are probed before removal; live sockets are left alone
- **CLI preference**: The `DaemonClient` automatically uses UDS when available, falling back to TCP
- **Disable**: Set `SJ_UDS_DISABLE=true`

---

## Complete Endpoint Table / 完整端點列表

All paths are prefixed with `/api/v1/` unless otherwise noted.

### Health & Info / 健康檢查與資訊

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/health` | No | Health check |
| GET | `/api/v1/info` | No | API information (version, simulation mode) |

### Auth / 認證端點

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/auth/usage` | Yes | Get API usage statistics |
| GET | `/api/v1/auth/accounts` | Yes | List all trading accounts |
| GET | `/api/v1/auth/ca_expiretime?person_id=<PID>` | Yes | Get CA certificate expiry time |
| POST | `/api/v1/auth/subscribe_trade` | Yes | Subscribe per-account trade/deal events (required before `order_event` SSE) |
| POST | `/api/v1/auth/unsubscribe_trade` | Yes | Unsubscribe per-account trade/deal events |

### Data / 行情資料

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/data/snapshots` | Yes | Get market data snapshots |
| POST | `/api/v1/data/ticks` | Yes | Get tick data |
| POST | `/api/v1/data/kbars` | Yes | Get K-bar (OHLCV) data |
| POST | `/api/v1/data/daily_quotes` | Yes | Get daily quotes |
| POST | `/api/v1/data/credit_enquire` | Yes | Get credit enquiry data |
| POST | `/api/v1/data/scanner` | Yes | Get scanner ranking data |
| GET | `/api/v1/data/regulatory_punish` | Yes | Get regulatory punish data |
| GET | `/api/v1/data/regulatory_notice` | Yes | Get regulatory notice data |
| POST | `/api/v1/data/short_stock_sources` | Yes | Get short stock sources |
| POST | `/api/v1/data/contracts` | Yes | Query contracts with pagination |
| GET | `/api/v1/data/contracts/{code}?security_type=<TYPE>` | Yes | Look up a single contract by code |

### Order / 委託

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/order/place_order` | Yes | Place a stock or futures order |
| POST | `/api/v1/order/cancel_order` | Yes | Cancel an order by trade ID |
| POST | `/api/v1/order/update_price` | Yes | Update an order's price |
| POST | `/api/v1/order/update_qty` | Yes | Update an order's quantity |
| POST | `/api/v1/order/trades` | Yes | Get all trades (update status + list) |
| POST | `/api/v1/order/place_comboorder` | Yes | Place a combo (spread) order |
| POST | `/api/v1/order/cancel_comboorder` | Yes | Cancel a combo order |
| POST | `/api/v1/order/combotrades` | Yes | Get all combo trades |
| POST | `/api/v1/order/stock_reserve_summary` | Yes | Get stock reserve summary |
| POST | `/api/v1/order/stock_reserve_detail` | Yes | Get stock reserve detail |
| POST | `/api/v1/order/reserve_stock` | Yes | Reserve stock |
| POST | `/api/v1/order/earmarking_detail` | Yes | Get earmarking detail |
| POST | `/api/v1/order/reserve_earmarking` | Yes | Reserve earmarking |
| POST | `/api/v1/order/order_deal_records` | Yes | Get order/deal records |

### Portfolio / 投資組合

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/portfolio/account_balance` | Yes | Get account balance |
| POST | `/api/v1/portfolio/margin` | Yes | Get margin info |
| POST | `/api/v1/portfolio/position_unit` | Yes | Get positions |
| POST | `/api/v1/portfolio/position_detail` | Yes | Get position detail |
| POST | `/api/v1/portfolio/settlements` | Yes | Get settlement list |
| POST | `/api/v1/portfolio/settlement` | Yes | Get settlements (legacy format) |
| POST | `/api/v1/portfolio/trading_limits` | Yes | Get trading limits |
| POST | `/api/v1/portfolio/profit_loss` | Yes | Get profit and loss |
| POST | `/api/v1/portfolio/profit_loss_detail` | Yes | Get profit and loss detail |
| POST | `/api/v1/portfolio/profitloss_sum` | Yes | Get profit and loss summary |

### Stream / 即時串流

All stream data endpoints use Server-Sent Events (SSE). Connect with `Accept: text/event-stream`.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/stream/subscribe` | Yes | Subscribe to market data |
| POST | `/api/v1/stream/unsubscribe` | Yes | Unsubscribe from market data |
| GET | `/api/v1/stream/receivers` | Yes | Get receiver info |
| GET | `/api/v1/stream/status` | Yes | Get connection status |
| GET | `/api/v1/stream/data` | Yes | All market data streams (combined SSE) |
| GET | `/api/v1/stream/data/tick_stk` | Yes | Stock tick data stream |
| GET | `/api/v1/stream/data/bidask_stk` | Yes | Stock bid/ask data stream |
| GET | `/api/v1/stream/data/tick_fop` | Yes | Futures/options tick data stream |
| GET | `/api/v1/stream/data/bidask_fop` | Yes | Futures/options bid/ask data stream |
| GET | `/api/v1/stream/data/quote_stk` | Yes | Stock quote data stream |
| GET | `/api/v1/stream/data/quote_fop` | Yes | Futures/options quote data stream |
| GET | `/api/v1/stream/data/order_event` | Yes | Order event data stream |

### Watchlist / 自選清單

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/watchlist` | Yes | List all watchlists |
| POST | `/api/v1/watchlist` | Yes | Create a new watchlist |
| GET | `/api/v1/watchlist/{id}` | Yes | Get a single watchlist by ID |
| PUT | `/api/v1/watchlist/{id}` | Yes | Sync (replace all) contracts in a watchlist |
| DELETE | `/api/v1/watchlist/{id}` | Yes | Delete a watchlist |
| POST | `/api/v1/watchlist/{id}/contracts` | Yes | Add contracts to a watchlist |
| DELETE | `/api/v1/watchlist/{id}/contracts` | Yes | Remove contracts from a watchlist |

### Apps / 自訂應用

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/apps` | Yes | List all uploaded apps |
| POST | `/api/v1/apps/{name}` | Yes | Upload files for an app (multipart, 50MB limit) |
| DELETE | `/api/v1/apps/{name}` | Yes | Delete an uploaded app |

App files are served publicly (no auth) at:

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/apps/{**path}` | No | Serve uploaded app files |

---

## Endpoint Details / 端點詳情

### Health & Info

#### GET `/api/v1/health`

Returns health status. Public, no auth required.

```json
{
  "status": "healthy",
  "version": "0.6.0",
  "timestamp": "2024-01-15T08:30:00Z"
}
```

#### GET `/api/v1/info`

Returns API server information including simulation mode.

```json
{
  "name": "Shioaji API Server",
  "version": "0.6.0",
  "description": "SinoPac Shioaji Cross-Platform Trading API HTTP Adaptor",
  "protocols": ["HTTP"],
  "simulation": true
}
```

### Auth Endpoints

#### GET `/api/v1/auth/accounts`

List all trading accounts associated with the session.

#### GET `/api/v1/auth/usage`

Get API usage statistics (connections, data transfer, limits).

#### GET `/api/v1/auth/ca_expiretime?person_id=<PERSON_ID>`

Get CA certificate expiry time for a person. The `person_id` query parameter is required.

#### POST `/api/v1/auth/subscribe_trade`

Subscribe to per-account trade/deal events on the Solace relay's P2P topic. **Required** before consuming `/api/v1/stream/data/order_event` in production — without it the SSE stream only emits heartbeats. Mirrors `POST /api/v1/stream/subscribe` for market data: explicit per-resource opt-in.

Request:

```json
{
  "broker_id": "9A95",
  "account_id": "1234567",
  "account_type": "S"
}
```

- `account_type`: `"S"` (stock) or `"F"` (futures/options).
- Omit `broker_id`/`account_id` to subscribe the default account of `account_type`.

Response (200):

```json
{
  "account": { "broker_id": "9A95", "account_id": "1234567", "...": "..." },
  "subscribe_trade": true,
  "ts": 1747200000
}
```

The server records the subscription in an in-memory registry; the daily client swap replays it automatically, so callers only need to subscribe once per server boot per account.

**Simulation:** the sw relay's `/auth/subscribe_trade` rejects simulation tokens (paper order events are delivered through a separate path). The server short-circuits this call client-side and returns a no-op success (`200`); nothing is added to the replay registry. Calling it is harmless but never required in simulation.

#### POST `/api/v1/auth/unsubscribe_trade`

Inverse of `subscribe_trade`. Removes the account from the registry only after the relay confirms unsubscribe. Same request shape; response has `"subscribe_trade": false`.

**Simulation:** returns `400 Bad Request` with a `ValueError`-style detail — simulation has no relay subscription to cancel. Don't call this in simulation.

### Data Endpoints

#### POST `/api/v1/data/snapshots`

Get market data snapshots for multiple contracts.

```json
{
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2330" },
    { "security_type": "STK", "exchange": "TSE", "code": "2317" }
  ]
}
```

#### POST `/api/v1/data/ticks`

Get tick data for a contract.

```json
{
  "contract": { "security_type": "STK", "exchange": "TSE", "code": "2330" },
  "date": "2024-01-15",
  "query_type": "LastCount",
  "last_cnt": 10
}
```

`query_type`: `"AllDay"` or `"LastCount"`. Optional fields: `time_start`, `time_end`.

#### POST `/api/v1/data/kbars`

Get K-bar (OHLCV) data.

```json
{
  "contract": { "security_type": "STK", "exchange": "TSE", "code": "2330" },
  "start": "2024-01-01",
  "end": "2024-01-31"
}
```

#### POST `/api/v1/data/daily_quotes`

Get daily quotes.

```json
{
  "date": "2024-01-15",
  "exclude": false
}
```

#### POST `/api/v1/data/credit_enquire`

Get credit enquiry data for contracts.

```json
{
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2330" }
  ]
}
```

#### POST `/api/v1/data/scanner`

Get scanner ranking data.

```json
{
  "scanner_type": "change-percent-rank",
  "date": "2024-01-15",
  "ascending": false,
  "count": 200
}
```

Scanner types: `change-percent-rank`, `change-price-rank`, `day-range-rank`, `volume-rank`, `amount-rank`, `tick-count-rank`.

#### GET `/api/v1/data/regulatory_punish`

Get regulatory punish data. No request body.

#### GET `/api/v1/data/regulatory_notice`

Get regulatory notice data. No request body.

#### POST `/api/v1/data/short_stock_sources`

Get short stock sources for contracts.

```json
{
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2330" }
  ]
}
```

#### POST `/api/v1/data/contracts`

Query contracts with pagination.

```json
{
  "security_type": "STK",
  "page": 1,
  "page_size": 1000
}
```

Use `"page": -1` to return all records. Response includes `contracts`, `page`, `page_size`, `max_page`, `total`.

#### GET `/api/v1/data/contracts/{code}?security_type=<TYPE>`

Look up a single contract by code. The `security_type` query parameter is required.

### Order Endpoints

#### POST `/api/v1/order/place_order`

Place a stock or futures order. The server dispatches by security type.

Stock order:
```json
{
  "contract": { "security_type": "STK", "exchange": "TSE", "code": "2330" },
  "stock_order": {
    "action": "Buy",
    "price": 600.0,
    "quantity": 1,
    "price_type": "LMT",
    "order_type": "ROD"
  }
}
```

Futures order:
```json
{
  "contract": { "security_type": "FUT", "exchange": "TAIFEX", "code": "TXFR1" },
  "futures_order": {
    "action": "Buy",
    "price": 17000.0,
    "quantity": 1,
    "price_type": "LMT",
    "order_type": "ROD"
  }
}
```

**Selecting a specific account.** Omit `account` to use the default
(first signed account of the matching type). To target a specific
account, supply just `broker_id` + `account_id` — the server resolves
the remaining fields (`person_id`, `signed`, `username`) from the
login session. Available since 1.5.12 (#234).

```json
{
  "contract": { "security_type": "STK", "exchange": "TSE", "code": "2330" },
  "stock_order": {
    "action": "Buy",
    "price": 600.0,
    "quantity": 1,
    "price_type": "LMT",
    "order_type": "ROD",
    "account": { "broker_id": "9A95", "account_id": "1234567" }
  }
}
```

#### POST `/api/v1/order/cancel_order`

```json
{ "trade_id": "abc123" }
```

#### POST `/api/v1/order/update_price`

```json
{ "trade_id": "abc123", "price": 605.0 }
```

#### POST `/api/v1/order/update_qty`

```json
{ "trade_id": "abc123", "quantity": 2 }
```

#### POST `/api/v1/order/trades`

List all trades (triggers status update before listing). Requires `AccountRequest`:

```json
{ "account_type": "S" }
```

#### POST `/api/v1/order/place_comboorder`

Place a combo (spread) order. Same account-selection rules as
`place_order`: omit `account` for default, or supply `{broker_id,
account_id}` to target a specific one (1.5.12+, #234).

```json
{
  "combo_contract": { ... },
  "order": {
    "...": "...",
    "account": { "broker_id": "F002", "account_id": "1234567" }
  }
}
```

#### POST `/api/v1/order/cancel_comboorder`

```json
{ "trade_id": "abc123" }
```

#### POST `/api/v1/order/combotrades`

List combo trades. Body: `AccountRequest`.

#### POST `/api/v1/order/stock_reserve_summary`

Get stock reserve summary. Body: `AccountRequest`.

#### POST `/api/v1/order/stock_reserve_detail`

Get stock reserve detail. Body: `AccountRequest`.

#### POST `/api/v1/order/reserve_stock`

Reserve stock.

```json
{
  "account_type": "S",
  "contract": { "security_type": "STK", "exchange": "TSE", "code": "2330" },
  "share": 1000
}
```

#### POST `/api/v1/order/earmarking_detail`

Get earmarking detail. Body: `AccountRequest`.

#### POST `/api/v1/order/reserve_earmarking`

Reserve earmarking.

```json
{
  "account_type": "S",
  "contract": { "security_type": "STK", "exchange": "TSE", "code": "2330" },
  "share": 1000,
  "price": 600.0
}
```

#### POST `/api/v1/order/order_deal_records`

Get order/deal records. Body: `AccountRequest`.

### Portfolio Endpoints

All portfolio endpoints accept `AccountRequest` (or extended request) as JSON body.

`AccountRequest` fields (all optional):
```json
{
  "account_type": "S",
  "broker_id": "9A00",
  "account_id": "1234567",
  "person_id": null
}
```

#### POST `/api/v1/portfolio/account_balance`

Get account balance. Body: `AccountRequest`.

#### POST `/api/v1/portfolio/margin`

Get margin info. Body: `AccountRequest` (resolves to futures account).

#### POST `/api/v1/portfolio/position_unit`

Get positions.

```json
{
  "account_type": "S",
  "unit": "Common"
}
```

`unit`: `"Common"` (default) or `"Share"`.

#### POST `/api/v1/portfolio/position_detail`

Get position detail.

```json
{
  "account_type": "S",
  "detail_id": 12345
}
```

#### POST `/api/v1/portfolio/settlements`

Get settlement list. Body: `AccountRequest`.

#### POST `/api/v1/portfolio/settlement`

Get settlements (legacy format). Body: `AccountRequest`.

#### POST `/api/v1/portfolio/trading_limits`

Get trading limits. Body: `AccountRequest`.

#### POST `/api/v1/portfolio/profit_loss`

Get profit and loss.

```json
{
  "account_type": "S",
  "begin_date": "2024-01-01",
  "end_date": "2024-01-31",
  "unit": "Common"
}
```

#### POST `/api/v1/portfolio/profit_loss_detail`

Get profit and loss detail.

```json
{
  "account_type": "S",
  "detail_id": 12345,
  "unit": "Common"
}
```

#### POST `/api/v1/portfolio/profitloss_sum`

Get profit and loss summary.

```json
{
  "account_type": "S",
  "begin_date": "2024-01-01",
  "end_date": "2024-01-31"
}
```

### Stream Endpoints (SSE)

All data stream endpoints use **Server-Sent Events**. Connect via GET with `Accept: text/event-stream`.

Every stream includes a **heartbeat** every 30 seconds to keep the connection alive:
```
event: heartbeat
data: {"type":"heartbeat","timestamp":"2024-01-15T08:30:00Z","connection_id":"42"}
```

#### Subscription workflow / 訂閱流程

1. **Subscribe**: POST `/api/v1/stream/subscribe`
2. **Connect**: GET the appropriate SSE endpoint
3. **Receive**: Process incoming events
4. **Unsubscribe**: POST `/api/v1/stream/unsubscribe`

Subscription request:
```json
{
  "security_type": "STK",
  "exchange": "TSE",
  "code": "2330",
  "target_code": null,
  "quote_type": "Tick",
  "intraday_odd": false
}
```

`quote_type`: `"Tick"`, `"BidAsk"`, `"Quote"`.

**Intraday odd lot 盤中零股**: set `"intraday_odd": true` (works for both `"Tick"` and `"BidAsk"`; stocks only). Regular and odd-lot subscriptions are independent — you can subscribe to both for the same stock and tell them apart on the SSE side via the `intraday_odd` flag carried on each event payload:

```json
{
  "security_type": "STK", "exchange": "TSE", "code": "2330",
  "quote_type": "Tick", "intraday_odd": true
}
```

```jsonc
// example tick_stk SSE event payload
event: tick_stk
data: {"code":"2330","close":"2235","volume":100,"intraday_odd":true, ...}
```

#### Combined stream

**GET `/api/v1/stream/data`** -- All data types merged into one SSE connection. Events are tagged:
- `tick_stk`, `bidask_stk`, `quote_stk` -- stock data
- `tick_fop`, `bidask_fop`, `quote_fop` -- futures/options data
- `order_event` -- order and deal events
- `heartbeat` -- keep-alive

#### Individual streams

| Endpoint | SSE Event Name | Description |
|----------|---------------|-------------|
| `/api/v1/stream/data/tick_stk` | `tick_stk` | Stock tick data |
| `/api/v1/stream/data/bidask_stk` | `bidask_stk` | Stock bid/ask data |
| `/api/v1/stream/data/tick_fop` | `tick_fop` | Futures/options tick data |
| `/api/v1/stream/data/bidask_fop` | `bidask_fop` | Futures/options bid/ask data |
| `/api/v1/stream/data/quote_stk` | `quote_stk` | Stock quote data |
| `/api/v1/stream/data/quote_fop` | `quote_fop` | Futures/options quote data |
| `/api/v1/stream/data/order_event` | `order_event` | Order/deal events |

#### Connection management / 連線管理

- **GET `/api/v1/stream/status`** -- returns `active_connections` count
- **GET `/api/v1/stream/receivers`** -- returns receiver availability info
- Connection count is tracked per SSE client. A `ConnectionGuard` ensures automatic cleanup when clients disconnect.

### Watchlist Endpoints

#### GET `/api/v1/watchlist`

List all watchlists.

#### POST `/api/v1/watchlist`

Create a new watchlist.

```json
{
  "name": "My Favorites",
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2330" },
    { "security_type": "STK", "exchange": "TSE", "code": "2317" }
  ]
}
```

#### GET `/api/v1/watchlist/{id}`

Get a single watchlist by ID.

#### PUT `/api/v1/watchlist/{id}`

Sync (replace all) contracts in a watchlist.

```json
{
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2454" }
  ]
}
```

#### DELETE `/api/v1/watchlist/{id}`

Delete a watchlist by ID.

#### POST `/api/v1/watchlist/{id}/contracts`

Add contracts to a watchlist.

```json
{
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2454" }
  ]
}
```

#### DELETE `/api/v1/watchlist/{id}/contracts`

Remove contracts from a watchlist.

```json
{
  "contracts": [
    { "security_type": "STK", "exchange": "TSE", "code": "2317" }
  ]
}
```

### Apps Endpoints

#### GET `/api/v1/apps`

List all uploaded apps.

```json
{ "apps": ["my-dashboard", "monitor"] }
```

#### POST `/api/v1/apps/{name}`

Upload files for an app via multipart form. Field name: `files`. Maximum total size: **50 MB**. Requires `Content-Length` header (chunked uploads rejected).

```bash
curl -X POST http://127.0.0.1:8080/api/v1/apps/my-dashboard \
  -F "files=@dist/index.html" \
  -F "files=@dist/main.js" \
  -F "files=@dist/style.css"
```

Response:
```json
{
  "name": "my-dashboard",
  "files": ["my-dashboard/index.html", "my-dashboard/main.js", "my-dashboard/style.css"]
}
```

#### DELETE `/api/v1/apps/{name}`

Delete an uploaded app and all its files.

#### GET `/apps/{**path}` (not under /api/v1/)

Serve uploaded app files. This is a public route (no auth required), served from memory. Path traversal attacks are blocked by `is_safe_path` validation.

---

## OpenAPI Documentation / OpenAPI 文件

The server auto-generates an OpenAPI 3.0 specification from endpoint annotations. **This is the authoritative source for the latest API format and payload schemas** — when in doubt, fetch `/openapi.json` from a running server to see exact field names, types, required/optional status, and enum values.

伺服器自動產生 OpenAPI 3.0 規格。**這是最權威的最新 API 格式與 payload schema 來源** — 有疑問時，從運行中的伺服器取得 `/openapi.json` 即可查看確切的欄位名稱、型別、必填/選填狀態及列舉值。

| Path | Description |
|------|-------------|
| `/openapi.json` | Raw OpenAPI 3.0 JSON specification |
| `/docs` | Interactive Scalar API documentation UI (browse, try endpoints) |

### Using OpenAPI to discover API format / 使用 OpenAPI 查詢 API 格式

#### Browse interactively / 互動式瀏覽

Open `http://localhost:8080/docs` in a browser. The Scalar UI lets you:
- Browse all endpoints grouped by tag (health, auth, data, order, portfolio, stream, watchlist, apps)
- See request body schema with field names, types, defaults, and enum values
- See response schema with all returned fields
- Try endpoints directly from the browser (send real requests)

#### Fetch the spec programmatically / 程式化取得規格

```bash
# Download the full OpenAPI spec
curl -s http://localhost:8080/openapi.json | jq .

# List all available endpoints
curl -s http://localhost:8080/openapi.json | jq '.paths | keys[]'

# Get the request schema for a specific endpoint (e.g., place_order)
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/v1/order/place_order"].post.requestBody.content["application/json"].schema'

# Get the response schema
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/v1/order/place_order"].post.responses["200"].content["application/json"].schema'

# List all schema definitions (reusable types)
curl -s http://localhost:8080/openapi.json | jq '.components.schemas | keys[]'

# Get a specific schema (e.g., StockOrder fields)
curl -s http://localhost:8080/openapi.json | jq '.components.schemas["StockOrder"]'

# Find all required fields for a request
curl -s http://localhost:8080/openapi.json | jq '.components.schemas["PlaceOrderRequest"].required'

# Get enum values for a field (e.g., Action)
curl -s http://localhost:8080/openapi.json | jq '.components.schemas["Action"]'
```

#### Why use OpenAPI instead of this doc / 為什麼用 OpenAPI 而非本文件

This reference documents the endpoint inventory and general usage patterns. But the OpenAPI spec is **generated from the actual Rust code** at runtime, so it is always up to date with:
- Exact field names and casing (e.g., `security_type` vs `securityType`)
- Required vs optional fields
- Enum variants (all valid values for Action, OrderType, PriceType, etc.)
- Nested object structures and array types
- Default values

When building a client in any language, **always fetch `/openapi.json` first** to confirm the exact payload format before writing code. The language reference guides (JAVASCRIPT.md, GO.md, etc.) show the general pattern and include OpenAPI client generation commands specific to each language. `/openapi.json` is the single source of truth for the current server version.

The OpenAPI spec includes:
- All endpoint definitions with request/response schemas
- Security scheme: `bearer_auth` (HTTP Bearer with format `<SJ_API_KEY>:<SJ_SEC_KEY>`)
- Tags: `health`, `info`, `auth`, `data`, `order`, `portfolio`, `stream`, `watchlist`, `apps`
- Component schemas for all request/response types

---

## Dashboard / 儀表板

A React-based dashboard is embedded into the binary at build time from `dashboard/dist/`.

| Path | Description |
|------|-------------|
| `/` | Dashboard index (single-page app) |
| `/{**path}` | Static assets (JS, CSS, images) with `index.html` fallback for SPA routing |

The dashboard is served via `static_embed` with `RustEmbed`, meaning it requires no external files at runtime.

---

## Custom App Embedding / 自訂應用嵌入

You can upload custom web applications to the running server:

1. **Upload** via `POST /api/v1/apps/{name}` with multipart form data
2. **Access** at `http://host:port/apps/{name}/index.html`
3. **List** all apps via `GET /api/v1/apps`
4. **Delete** via `DELETE /api/v1/apps/{name}`

Apps are stored in memory (not persisted to disk). They are served publicly at `/apps/` without authentication, similar to the built-in dashboard.

---

## Middleware Stack / 中介層堆疊

The server applies the following middleware in order:

| Middleware | Description |
|-----------|-------------|
| `inject(state)` | Inject `ServerState` into the request depot |
| `Cors` | CORS with `allow_origin("*")`, common methods and headers |
| `Logger` | HTTP request/response logging |
| `CatchPanic` | Recover from panics in handlers |
| `Compression` | gzip compression (default level) |
| `api_key_auth` | Bearer token authentication (only on non-localhost, only on protected routes) |
| `max_size` | 50MB upload size limit (only on app upload endpoint) |

### Router structure / 路由結構

```
/
├── /api/v1/
│   ├── (public)     /health, /info
│   └── (protected)  /auth/*, /data/*, /order/*, /portfolio/*, /stream/*, /watchlist/*, /apps/*
├── /openapi.json
├── /docs
├── /apps/{**path}      (uploaded apps, public)
└── /{**path}           (dashboard SPA, public)
```

---

## Error Responses / 錯誤回應

All errors return JSON:

```json
{
  "code": 400,
  "message": "Description of the error",
  "details": null
}
```

Common status codes:

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Bad request (invalid parameters, missing fields) |
| 401 | Unauthorized (missing or invalid credentials) |
| 404 | Not found (contract, watchlist, app) |
| 413 | Payload too large (app upload exceeds 50MB) |
| 500 | Internal server error |
