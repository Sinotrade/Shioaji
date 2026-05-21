---
name: shioaji
description: |
  ALWAYS USE THIS SKILL when working with Shioaji, rshioaji, SinoPac, or Taiwan financial markets.
  Covers ALL access layers: Python native binding (sync and async), CLI tool (`shioaji` command),
  HTTP API server with SSE streaming, dashboard with custom app embedding, and multi-language SDK
  integration (JavaScript/TypeScript, Go, C/C++, C#, Rust, Java/Kotlin).
  Covers: placing/modifying/canceling stock/futures/options orders (buy, sell, limit, market, ROD, IOC, FOK,
  margin, short selling, odd lot, combo orders), real-time streaming via Python callbacks or HTTP SSE
  (tick, bidask, quote), historical kbars/ticks/snapshots, account balance/margin/positions/P&L,
  watchlists, scanners, reserve orders, and automated trading systems on TWSE/TPEX/TAIFEX.
  Use this skill when users mention: shioaji, rshioaji, sinopac, Taiwan stocks, TWSE, TPEX, TAIFEX, 永豐金,
  trading API, stock order, futures order, options order, market data streaming, SSE streaming,
  shioaji CLI, shioaji server, shioaji HTTP API, shioaji dashboard, custom trading app,
  or building trading clients in any programming language against the shioaji server.
  使用 Shioaji、rshioaji、永豐金證券、台灣金融市場交易時務必使用本技能。
  涵蓋：Python 原生綁定（同步/非同步）、CLI 命令列工具、HTTP API 伺服器（SSE 即時串流）、
  儀表板（自訂應用嵌入）、多語言 SDK 整合（JS/TS、Go、C/C++、C#、Rust、Java/Kotlin）。
---

# Shioaji Trading API

Shioaji is SinoPac's **cross-language, cross-platform** trading API for Taiwan financial markets (TWSE/TPEX/TAIFEX). The Rust reimplementation (rshioaji) transforms Shioaji from a Python-only library into a universal trading platform — **any programming language** can now trade Taiwan markets through the HTTP API server.

Shioaji 是永豐金證券的**跨語言、跨平台**交易 API。Rust 重新實作（rshioaji）將 Shioaji 從 Python 專屬函式庫轉變為通用交易平台 — **任何程式語言**都能透過 HTTP API 伺服器交易台灣市場。

Three access layers:

- **Python** — native PyO3 binding (`import shioaji`) for best performance, sync and async
- **CLI** — `shioaji` command-line tool for server management, trading, and data queries
- **HTTP API + SSE** — REST endpoints + real-time streaming at `localhost:8080`, accessible from JS/TS, Go, C/C++, C#, Rust, Java/Kotlin, or any HTTP client

> **Install**: `claude plugin marketplace add Sinotrade/rshioaji` → `claude plugin install rshioaji`
> This can coexist with the old `Sinotrade/Shioaji` plugin (different name). At production release, plugin name changes to `shioaji`.

**Official Docs**: https://sinotrade.github.io/

---

## Task Routing — "I want to..."

For most tasks, load only 1-2 files. Use both axes: **what** (task) + **how** (access method).

### Axis 1: What do you want to do?

| Task | Load File |
|------|-----------|
| Install, login, API keys, CA cert, simulation, env vars, constants | [PREPARE.md](references/PREPARE.md) |
| Look up contract codes, attributes, security types | [CONTRACTS.md](references/CONTRACTS.md) |
| Place, modify, cancel orders; combos; order events | [ORDERS.md](references/ORDERS.md) |
| Reserve shares for disposition/attention stocks | [RESERVE.md](references/RESERVE.md) |
| Subscribe real-time quotes, tick/bidask/quote callbacks, SSE streams | [STREAMING.md](references/STREAMING.md) |
| Historical ticks, K-bars, snapshots, scanners, credit enquiry | [MARKET_DATA.md](references/MARKET_DATA.md) |
| Account balance, margin, positions, P&L, settlements, limits | [ACCOUNTING.md](references/ACCOUNTING.md) |
| Manage watchlists (CRUD, add/remove contracts) | [WATCHLIST.md](references/WATCHLIST.md) |
| Non-blocking mode, quote binding, stop orders, advanced patterns | [ADVANCED.md](references/ADVANCED.md) |
| Errors, connection issues, troubleshooting | [TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) |

### Axis 2: What language/access method?

| Access Method | Additional File | Notes |
|---------------|-----------------|-------|
| **Python** (sync or async) | None — task refs include Python examples | Default path |
| **CLI** (`shioaji` command) | [CLI.md](references/CLI.md) | Task ref (concept) + CLI.md (commands) |
| **HTTP API** (any language) | [HTTP_API.md](references/HTTP_API.md) | Canonical endpoint inventory |
| **JavaScript/TypeScript** | [JAVASCRIPT.md](references/JAVASCRIPT.md) | Complete project guide |
| **Go** | [GO.md](references/GO.md) | Complete project guide |
| **C/C++** | [CPP.md](references/CPP.md) | Complete project guide |
| **C#** | [CSHARP.md](references/CSHARP.md) | Complete project guide |
| **Rust** | [RUST.md](references/RUST.md) | HTTP client guide |
| **Java/Kotlin** | [JAVA.md](references/JAVA.md) | Complete project guide |

**Python users**: load only the task reference (Axis 1).
**CLI users**: load the task reference + CLI.md.
**Other languages**: load the task reference + language reference (which covers HTTP setup).

---

## Quick Start

### Python
```python
import shioaji as sj
api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")
```

### CLI
```bash
uv tool install rshioaji
export SJ_API_KEY=YOUR_KEY SJ_SEC_KEY=YOUR_SECRET
shioaji server start           # start HTTP server (simulation)
shioaji order place --code 2330 --action Buy --price 580 --quantity 1
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

## Rate Limits

| Category | Limit |
|----------|-------|
| Daily Traffic | 500MB–10GB (based on trading volume) |
| Quote Query | 50 requests / 5 sec |
| Accounting Query | 25 requests / 5 sec |
| Connections | 5 per person ID |
| Daily Logins | 1000 times |

---

## Error Handling

```python
try:
    trade = api.place_order(contract, order)
except Exception as e:
    print(f"Order failed: {e}")
```

HTTP API returns JSON errors: `{"code": 400, "message": "...", "details": "..."}`

---

## Logout

```python
api.logout()
```
