---
name: shioaji
description: |
  Use this skill whenever the user works with Shioaji, SinoPac (永豐金), or Taiwan
  financial markets (TWSE/TPEX/TAIFEX) — even if they don't name the library.
  Covers all access layers: Python binding (sync/async), `shioaji` CLI, HTTP API
  server with SSE streaming, dashboard with custom-app embedding, and multi-language
  HTTP clients (JavaScript/TypeScript, Go, C/C++, C#, Rust, Java/Kotlin).
  Tasks covered: place/modify/cancel stock/futures/options orders (limit, market,
  ROD/IOC/FOK, margin, short, odd-lot, combo); real-time streaming (tick, bidask,
  quote) via Python callbacks or HTTP SSE; historical kbars/ticks/snapshots;
  account balance/margin/positions/P&L; watchlists, scanners, reserve orders;
  building HTTP/SSE clients in any language against the Shioaji server.
  Trigger keywords: shioaji, sinopac, 永豐金, 台股, TWSE, TPEX, TAIFEX,
  下單, 即時行情, 台灣股票交易, shioaji CLI, shioaji server, SSE streaming.
  Not for: US/HK markets, Interactive Brokers, generic ta-lib/pandas indicators
  unless paired with Shioaji data.
---

# Shioaji Trading API

Shioaji is SinoPac's **cross-language, cross-platform** trading API for Taiwan financial markets (TWSE/TPEX/TAIFEX). It includes Python bindings, a CLI, and an HTTP API server that lets **any programming language** trade Taiwan markets.

Shioaji 是永豐金證券的**跨語言、跨平台**交易 API，提供 Python 綁定、CLI 與 HTTP API 伺服器，讓**任何程式語言**都能透過 HTTP API 交易台灣市場。

Three access layers / 三種存取層：

- **Python** — native PyO3 binding (`import shioaji`) for best performance, sync and async
- **CLI** — `shioaji` command-line tool for server management, trading, and data queries
- **HTTP API + SSE** — REST endpoints + real-time streaming at `localhost:8080`, accessible from JS/TS, Go, C/C++, C#, Rust, Java/Kotlin, or any HTTP client

## How to Use References / 如何使用參考文件

Answer users directly from the bundled references. Do not route users to external documentation pages as a substitute for answering. This skill uses Shioaji 1.5 as the baseline; use [MIGRATION.md](references/MIGRATION.md) only for legacy/deprecated idioms. Response handling always belongs in the matching functional reference. When an exact command flag, request field, or response schema must be confirmed, use installed CLI `--help` or the running server's `/openapi.json`.

**Cross-access-layer response guardrails / 跨層回應守則：**

- Do not infer HTTP/SSE/CLI fields from Python wrapper attributes.
- Other languages (JS/Go/Rust/C#/C++/Java) use HTTP/SSE response shapes, not Python objects.
- If a response contains `success=false`, an error code, or an operation status/message, branch on that field before continuing.
- Empty lists and `PendingSubmit` are not final failure/success signals; check the matching functional reference before deciding the next step.

**Token-efficient lookup / 精簡載入：**

- Choose the functional reference first; search inside it for endpoint, method, error text, response type, or headings like `Response and Decision Summary`, `Prerequisites`.
- Read the smallest matching section before loading long examples.
- Load CLI/HTTP/language references only when implementation details (transport setup, SSE parser, auth/error handling, OpenAPI generation) are needed; keep endpoint-specific payload and response decisions in the functional reference.

---

## Task Routing — "I want to..." / 任務路由

For most tasks, load only 1-2 files. Use both axes: **what** (task) + **how** (access method).

Routing rule: choose the functional reference first, then add the access-method reference only when needed. Functional references own the workflow, payload rules, response shapes, and decision logic for that task. Language references explain how to send requests, receive responses, stream SSE, add auth headers, handle errors, and generate typed clients; they must not restate endpoint-specific business rules. Use [HTTP_API.md](references/HTTP_API.md) for endpoint inventory and `/openapi.json` for exact installed-server schemas.

### Axis 1: What do you want to do? / 任務

| Task | Load File |
|------|-----------|
| Migrate legacy code or fix deprecated Shioaji idioms | [MIGRATION.md](references/MIGRATION.md) |
| Install, login, API keys, CA cert, simulation, env vars, constants | [PREPARE.md](references/PREPARE.md) |
| Look up contract codes, attributes, security types | [CONTRACTS.md](references/CONTRACTS.md) |
| Place, modify, cancel orders; combos; `order_deal_event` active order/deal reports (Python callbacks, HTTP order-event SSE) | [ORDERS.md](references/ORDERS.md) |
| Reserve shares for disposition/attention stocks | [RESERVE.md](references/RESERVE.md) |
| Subscribe real-time quotes, tick/bidask/quote callbacks, SSE streams | [STREAMING.md](references/STREAMING.md) |
| Historical ticks, K-bars, snapshots, scanners, credit enquiry | [MARKET_DATA.md](references/MARKET_DATA.md) |
| Account balance, margin, positions, P&L, settlements, limits | [ACCOUNTING.md](references/ACCOUNTING.md) |
| Manage watchlists (CRUD, add/remove contracts) | [WATCHLIST.md](references/WATCHLIST.md) |
| Non-blocking mode, quote binding, stop orders, advanced patterns | [ADVANCED.md](references/ADVANCED.md) |
| Errors, connection issues, troubleshooting | [TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) |

### Axis 2: What language/access method? / 語言或存取方式

| Access Method | Additional File | Notes |
|---------------|-----------------|-------|
| **Python** (sync or async) | None — task refs include Python examples | Default path |
| **CLI** (`shioaji` command) | [CLI.md](references/CLI.md) | Task ref (concept) + CLI.md (commands) |
| **HTTP API** (any language) | [HTTP_API.md](references/HTTP_API.md) | Canonical endpoint inventory |
| **JavaScript/TypeScript** | [JAVASCRIPT.md](references/JAVASCRIPT.md) | HTTP/SSE client patterns |
| **Go** | [GO.md](references/GO.md) | HTTP/SSE client patterns |
| **C/C++** | [CPP.md](references/CPP.md) | HTTP/SSE client patterns |
| **C#** | [CSHARP.md](references/CSHARP.md) | HTTP/SSE client patterns |
| **Rust** | [RUST.md](references/RUST.md) | HTTP/SSE client patterns |
| **Java/Kotlin** | [JAVA.md](references/JAVA.md) | HTTP/SSE client patterns |

**Python users**: load only the task reference (Axis 1).
**CLI users**: load the task reference + CLI.md.
**Other languages**: load the task reference + language reference. For example, "use JS to place an order" means load [ORDERS.md](references/ORDERS.md) for payload and `Trade` decision logic, plus [JAVASCRIPT.md](references/JAVASCRIPT.md) for `fetch`/SSE implementation patterns.

---

## Quick Start / 快速開始

> **Install / 安裝**: `claude plugin marketplace add Sinotrade/Shioaji` → `claude plugin install shioaji`

### Python
```python
import shioaji as sj
api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")
```

### CLI
```bash
uv tool install shioaji

# .env in the directory where `shioaji server start` runs:
# SJ_API_KEY=YOUR_API_KEY
# SJ_SEC_KEY=YOUR_SECRET_KEY
# SJ_CA_PATH=your/ca/path/Sinopac.pfx
# SJ_CA_PASSWD=YOUR_CA_PASSWORD
# SJ_PRODUCTION=false

shioaji server start           # reads .env and starts HTTP server
shioaji auth accounts -f json  # verify login/account readiness before any order task
```

### HTTP API (any language)
```bash
# Server must be running first (see CLI above)
curl http://localhost:8080/api/v1/auth/accounts
curl -X POST http://localhost:8080/api/v1/data/snapshots \
  -H "Content-Type: application/json" \
  -d '{"contracts":[{"security_type":"STK","exchange":"TSE","code":"2330"}]}'
```

See [PREPARE.md](references/PREPARE.md) for full installation and setup.

---

## Simulation vs Production Safety / 模擬與正式環境安全

> **WARNING 警告**: Always verify the server mode before placing orders. Production mode executes real trades with real money.
> 下單前務必確認伺服器模式。正式環境會使用真實資金進行真實交易。

- **Default**: simulation mode (no flag needed)
- **Check mode**: `shioaji server check` (CLI) or `GET /api/v1/info` (HTTP — returns `simulation` field)
- **Switch to production 切換至正式環境**: `shioaji server start --production` or `SJ_PRODUCTION=true`
- **Switch back to simulation 切回模擬環境**: `shioaji server stop` then `shioaji server start` (without `--production`)

---

## Rate Limits / 速率限制

| Category | Limit |
|----------|-------|
| Daily Traffic | 500MB–10GB (based on trading volume) |
| Quote Query | 50 requests / 5 sec |
| Accounting Query | 25 requests / 5 sec |
| Connections | 5 per person ID |
| Daily Logins | 1000 times |

---

## Error Handling / 錯誤處理

HTTP API returns JSON errors: `{"code": 400, "message": "...", "details": "..."}`

Check the task reference before retrying. For example, empty market-data responses, `PendingSubmit` order status, and `success=false` subscription responses each require different next steps.

---

## Logout / 登出

```python
api.logout()
```

---

For task examples, see the functional reference (Axis 1). For transport and client patterns, see the language reference (Axis 2).
任務範例請見功能參考（軸 1）；傳輸與客戶端模式請見語言參考（軸 2）。
