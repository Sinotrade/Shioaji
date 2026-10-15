# Shioaji CLI Command Reference / Shioaji CLI 指令參考

> Command inventory for the packaged `shioaji` CLI.
> When an exact flag or option must be confirmed on an installed version, use `shioaji --help` or the command's `--help`.

---

## Table of Contents / 目錄

1. [Overview / 概覽](#overview--概覽)
2. [Global Flags / 全域旗標](#global-flags--全域旗標)
3. [Output Formats / 輸出格式](#output-formats--輸出格式)
4. [Environment Variables / 環境變數](#environment-variables--環境變數)
5. [Command Tree / 指令樹](#command-tree--指令樹)
6. [server -- Server Management / 伺服器管理](#server----server-management--伺服器管理)
   - [server start](#server-start)
   - [server check](#server-check)
   - [server status](#server-status)
   - [server stop](#server-stop)
7. [auth -- Authentication / 認證](#auth----authentication--認證)
   - [auth accounts](#auth-accounts)
   - [auth usage](#auth-usage)
   - [auth ca-expiretime](#auth-ca-expiretime)
   - [auth subscribe-trade](#auth-subscribe-trade)
   - [auth unsubscribe-trade](#auth-unsubscribe-trade)
8. [apps -- Custom Dashboard Apps / 自訂儀表板應用](#apps----custom-dashboard-apps--自訂儀表板應用)
   - [apps list](#apps-list)
   - [apps upload](#apps-upload)
   - [apps delete](#apps-delete)
9. [data -- Market Data / 行情資料](#data----market-data--行情資料)
   - [data ticks](#data-ticks)
   - [data kbars](#data-kbars)
   - [data scanner](#data-scanner)
   - [data stream](#data-stream)
   - [data snapshots](#data-snapshots)
   - [data daily-quotes](#data-daily-quotes)
   - [data credit-enquire](#data-credit-enquire)
   - [data short-stock-sources](#data-short-stock-sources)
   - [data regulatory](#data-regulatory)
10. [order -- Order Management / 委託管理](#order----order-management--委託管理)
   - [order place](#order-place)
   - [order cancel](#order-cancel)
   - [order list](#order-list)
   - [order update-price](#order-update-price)
   - [order update-qty](#order-update-qty)
   - [order events](#order-events)
11. [portfolio -- Portfolio Queries / 投資組合查詢](#portfolio----portfolio-queries--投資組合查詢)
    - [portfolio balance](#portfolio-balance)
    - [portfolio positions](#portfolio-positions)
    - [portfolio margin](#portfolio-margin)
    - [portfolio position-detail](#portfolio-position-detail)
    - [portfolio profit-loss](#portfolio-profit-loss)
    - [portfolio profit-loss-detail](#portfolio-profit-loss-detail)
    - [portfolio profit-loss-summary](#portfolio-profit-loss-summary)
    - [portfolio trading-limits](#portfolio-trading-limits)
    - [portfolio settlements](#portfolio-settlements)
12. [reserve -- Stock Reserve & Earmarking / 股票預收券款](#reserve----stock-reserve--earmarking--股票預收券款)
    - [reserve summary](#reserve-summary)
    - [reserve detail](#reserve-detail)
    - [reserve stock](#reserve-stock)
    - [reserve earmarking-detail](#reserve-earmarking-detail)
    - [reserve earmarking](#reserve-earmarking)
13. [watchlist -- Watchlist Management / 自選股管理](#watchlist----watchlist-management--自選股管理)
    - [watchlist list](#watchlist-list)
    - [watchlist create](#watchlist-create)
    - [watchlist show](#watchlist-show)
    - [watchlist sync](#watchlist-sync)
    - [watchlist delete](#watchlist-delete)
    - [watchlist add](#watchlist-add)
    - [watchlist remove](#watchlist-remove)
14. [utils -- Utility Commands / 工具指令](#utils----utility-commands--工具指令)
    - [utils token list](#utils-token-list)
    - [utils token show](#utils-token-show)
    - [utils token status](#utils-token-status)
    - [utils token clean](#utils-token-clean)
    - [utils api check](#utils-api-check)
15. [tree -- Show Command Tree / 顯示指令樹](#tree----show-command-tree--顯示指令樹)
16. [completions -- Shell Completions / Shell 自動完成](#completions----shell-completions--shell-自動完成)
17. [version -- Print Version / 顯示版本](#version----print-version--顯示版本)
18. [Daemon Architecture / 背景服務架構](#daemon-architecture--背景服務架構)
19. [UDS Support / Unix Domain Socket 支援](#uds-support--unix-domain-socket-支援)

---

## Overview / 概覽

The `shioaji` binary is a single CLI that doubles as:
- **A command-line client** for querying market data, placing orders, and managing portfolios.
- **A daemon server** (`shioaji server start`) that hosts the HTTP API.

All data-path commands (`auth`, `apps`, `data`, `order`, `portfolio`, `reserve`, `watchlist`) communicate with the daemon via HTTP (preferring UDS on Unix). If no daemon is running, the CLI auto-starts one (`ensure_daemon`).
Use the matching functional reference when an agent needs to reason about the response objects behind CLI output; `toon` is the default output format.

Binary name: `shioaji`

```
shioaji [OPTIONS] <COMMAND>
```

---

## Global Flags / 全域旗標

| Flag | Short | Description |
|------|-------|-------------|
| `--verbose` | `-v` | Enable verbose (debug-level) output |
| `--format <FORMAT>` | `-f` | Output format: `toon` (default), `json`, `human` |

These flags are **global** -- they apply to every subcommand.

---

## Output Formats / 輸出格式

Three formats are supported. **No CSV output exists.**

| Format | Description | Notes |
|--------|-------------|-------|
| `toon` | Token-Oriented Object Notation (default) | Optimized for LLM token efficiency; used by default for all commands |
| `json` | Pretty-printed JSON | Standard machine-readable output; activate with `-f json` |
| `human` | Human-readable display | Visual formatting (e.g., usage bars); currently `toon` and `human` share the TOON serializer except where `human` has special rendering like `auth usage` |

Example:
```bash
shioaji auth accounts -f json
shioaji data ticks --code 2330 -f toon
```

---

## Environment Variables / 環境變數

### Authentication / 認證
| Variable | Description |
|----------|-------------|
| `SJ_API_KEY` | API key for Shioaji authentication (required) |
| `SJ_SEC_KEY` | Secret key for Shioaji authentication (required) |

### Client / 客戶端
| Variable | Description |
|----------|-------------|
| `SJ_PROXY` | HTTP proxy URL |
| `SJ_CA_PATH` | Path to CA certificate file |
| `SJ_CA_PASSWD` | CA certificate password |
| `SJ_HOME_PATH` | Custom home directory for token pool, contracts, and cache |
| `SJ_TIMEOUT` | Solace request-reply timeout in milliseconds (default: 60000) |

### Server / 伺服器
| Variable | Description |
|----------|-------------|
| `SJ_PRODUCTION` | Enable production mode (default: false, simulation) |
| `SJ_HTTP_ADDR` | Server bind address (default: 127.0.0.1:8080) |
| `SJ_HTTP_CORS` | Enable CORS (default: true) |
| `SJ_HTTP_TIMEOUT` | HTTP request timeout in seconds (default: 30) |
| `SJ_HTTP_LOG` | Enable HTTP request logging (default: true) |

### UDS / Unix Domain Socket
| Variable | Description |
|----------|-------------|
| `SJ_UDS_PATH` | Custom UDS socket path |
| `SJ_UDS_DISABLE` | Disable UDS transport (default: false) |

---

## Command Tree / 指令樹

```
shioaji
├── server
│   ├── start       [--production] [--no-open]
│   ├── check
│   ├── status      [--streams]
│   └── stop
├── auth
│   ├── accounts
│   ├── usage
│   ├── ca-expiretime     --person-id <PERSON_ID>
│   ├── subscribe-trade   [--account-type S] [--account]
│   └── unsubscribe-trade [--account-type S] [--account]
├── apps
│   ├── list
│   ├── upload      --name <NAME> (--dir <DIR> | --file <PATH>...)
│   └── delete      --name <NAME>
├── data
│   ├── ticks       --code <CODE> [--date] [--last 10] [--all] [--security-type STK] [--exchange TSE]
│   ├── kbars       --code <CODE> [--start] [--end] [--security-type STK] [--exchange TSE]
│   ├── scanner     [--scanner-type change-percent-rank] [--date] [--ascending] [--count 50]
│   ├── stream      --code <CODE> [--quote-type tick] [--security-type STK] [--intraday-odd]
│   ├── snapshots   --codes <CODES> [--security-type STK] [--exchange TSE]
│   ├── daily-quotes [--date] [--exclude-warrant]
│   ├── credit-enquire --codes <CODES> [--security-type STK] [--exchange TSE]
│   ├── short-stock-sources --codes <CODES> [--security-type STK] [--exchange TSE]
│   └── regulatory  [--type punish]
├── order
│   ├── place       --code <CODE> --action <ACTION> --quantity <QTY> [--price 0] [--price-type lmt] [--order-type rod] [--order-lot] [--order-cond] [--octype] [--account] [--security-type STK] [--no-wait]
│   ├── cancel      --id <ID> [--no-wait]
│   ├── list        [--account]
│   ├── update-price --id <ID> --price <PRICE> [--no-wait]
│   ├── update-qty  --id <ID> --quantity <QTY> [--no-wait]
│   └── events
├── portfolio
│   ├── balance     [--account]
│   ├── positions   [--account-type S] [--account] [--unit common]
│   ├── margin      [--account]
│   ├── position-detail     --detail-id <ID> [--account-type S] [--account]
│   ├── profit-loss         [--account-type S] [--account] [--begin-date] [--end-date] [--unit common]
│   ├── profit-loss-detail  --detail-id <ID> [--account-type S] [--account] [--unit common]
│   ├── profit-loss-summary [--account-type S] [--account] [--begin-date] [--end-date]
│   ├── trading-limits      [--account]
│   └── settlements         [--account]
├── reserve
│   ├── summary     [--account]
│   ├── detail      [--account]
│   ├── stock       --code <CODE> --share <SHARE> [--account]
│   ├── earmarking-detail [--account]
│   └── earmarking  --code <CODE> --share <SHARE> --price <PRICE> [--account]
├── watchlist
│   ├── list
│   ├── create      --name <NAME> [--codes <CODES>] [--security-type STK]
│   ├── show        --id <ID>
│   ├── sync        --id <ID> --codes <CODES> [--security-type STK]
│   ├── delete      --id <ID>
│   ├── add         --id <ID> --codes <CODES> [--security-type STK]
│   └── remove      --id <ID> --codes <CODES> [--security-type STK]
├── utils
│   ├── token       [-k <KEY>] [-s <SECRET>]
│   │   ├── list    [--detailed]
│   │   ├── show    [--all | --slot <N>]
│   │   ├── status
│   │   └── clean   [--dry-run] [--all | --slot <N>]
│   └── api
│       └── check   [--production]
├── tree            [--params] [--all]
├── completions     <SHELL>
└── version
```

---

## Simulation vs Production Safety / 模擬與正式環境安全

> **WARNING 警告**: Always verify you are in the correct mode before placing orders. Running order commands against a production server will execute real trades with real money.
>
> 下單前務必確認目前運行模式。對正式環境伺服器執行委託指令將會使用真實資金進行真實交易。

The server starts in **simulation mode by default**. No flag needed.

```bash
# Check current mode 確認目前模式
shioaji server check      # shows simulation/production and auth status
shioaji server status     # shows daemon status including mode

# Start in simulation (default) 啟動模擬模式（預設）
shioaji server start

# Start in production 啟動正式環境
shioaji server start --production
# or via env var 或透過環境變數
SJ_PRODUCTION=true shioaji server start

# Switch back to simulation 切回模擬環境
shioaji server stop
shioaji server start              # without --production
```

Before running any `shioaji order` command, run `shioaji server check` to confirm the mode.
在執行任何 `shioaji order` 指令前，先執行 `shioaji server check` 確認模式。

---

## server -- Server Management / 伺服器管理

```
shioaji server [--production] [SUBCOMMAND]
```

If no subcommand is given, defaults to `start`.
Use `--no-open` on either `shioaji server` or `shioaji server start` when the server should not auto-open the dashboard/API docs in a browser.

### server start

Start the API server (daemon). Authenticates with SJ_API_KEY/SJ_SEC_KEY and begins serving HTTP.

```bash
shioaji server start
shioaji server start --production
shioaji server start --prod        # visible alias
shioaji server start --no-open     # do not auto-open browser
```

| Flag | Description |
|------|-------------|
| `--production` / `--prod` | Run in production mode (default: simulation). Also settable via `SJ_PRODUCTION` env var |
| `--no-open` | Do not auto-open the dashboard/API docs browser window |

### server check

Check server connectivity and authentication. Sends a health check to the running daemon.

```bash
shioaji server check
```

### server status

Show daemon status (running, PID, port, health, simulation mode).

```bash
shioaji server status
shioaji server status --streams     # also fetch stream diagnostics 同時取得串流診斷
```

| Flag | Description |
|------|-------------|
| `--streams` | Additionally fetch stream diagnostics from the running daemon: `GET /api/v1/stream/receivers` and `GET /api/v1/stream/status` (active SSE connections). If the daemon is not running or unhealthy, the stream fields are skipped gracefully. 若 daemon 未運行則自動略過串流欄位 |

### server stop

Stop the running daemon.

```bash
shioaji server stop
```

---

## auth -- Authentication / 認證

```
shioaji auth <SUBCOMMAND>
```

### auth accounts

List all trading accounts associated with the authenticated session.

```bash
shioaji auth accounts
shioaji auth accounts -f json
```

### auth usage

Show API usage statistics (connections, data transfer, remaining quota).

```bash
shioaji auth usage
shioaji auth usage -f json
```

Note: When using the default `toon` format, usage automatically switches to `human` format for a visual bar display. Use `-f json` for machine-readable output.

### auth ca-expiretime

Get the CA certificate expiry time for a person ID. 查詢 CA 憑證到期時間。

```bash
shioaji auth ca-expiretime --person-id A123456789
shioaji auth ca-expiretime --person-id A123456789 -f json
```

| Flag | Default | Description |
|------|---------|-------------|
| `--person-id` | (required) | Person ID bound to the CA certificate (e.g. A123456789) |

Returns `person_id` and `expire_time`. Requires the CA certificate to be activated on the server (see PREPARE.md).

### auth subscribe-trade

Subscribe to per-account trade/deal events. Mirrors Python `api.subscribe_trade(account)`. In production, the relay only forwards order/deal events for accounts that have an active trade subscription — without it the order event stream stays empty.

訂閱指定帳戶的委託/成交事件。正式環境下未訂閱的帳戶不會收到委託回報。

```bash
shioaji auth subscribe-trade                              # default stock account
shioaji auth subscribe-trade --account-type F             # default futures account
shioaji auth subscribe-trade --account 9A95-9816502       # specific account
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (default account) | Account in BROKER_ID-ACCOUNT_ID format (e.g. 9A00-1234567) |

### auth unsubscribe-trade

Unsubscribe from per-account trade/deal events. Mirrors Python `api.unsubscribe_trade(account)`. 取消訂閱帳戶委託/成交事件。

```bash
shioaji auth unsubscribe-trade
shioaji auth unsubscribe-trade --account 9A95-9816502 --account-type S
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (default account) | Account in BROKER_ID-ACCOUNT_ID format |

---

## apps -- Custom Dashboard Apps / 自訂儀表板應用

Manage custom apps served by the dashboard (uploaded files are served at `/apps/<NAME>/` on the running server). 管理儀表板自訂應用（上傳的檔案會在伺服器的 `/apps/<NAME>/` 路徑提供）。

```
shioaji apps <SUBCOMMAND>
```

### apps list

List uploaded custom dashboard apps. 列出已上傳的自訂應用。

```bash
shioaji apps list
shioaji apps list -f json
```

### apps upload

Upload files for a custom dashboard app (multipart upload to `POST /api/v1/apps/<NAME>`, 50MB total limit). Use `--dir` to upload a whole built directory (recommended), or repeat `--file` for individual files. 上傳自訂應用檔案（總大小上限 50MB）。建議用 `--dir` 上傳整個建置目錄，或重複 `--file` 上傳個別檔案。

```bash
# Recommended: upload a whole built directory, preserving structure 建議：上傳整個建置目錄並保留結構
shioaji apps upload --name myapp --dir dist

# Or individual files 或個別檔案
shioaji apps upload --name myapp --file index.html
shioaji apps upload --name myapp --file index.html --file assets/app.js
```

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | (required) | App name (served at `/apps/<NAME>/` on the dashboard) |
| `--dir` | (none) | Directory to upload recursively, preserving structure relative to it (e.g. `dist/assets/main.js` → `assets/main.js`). Mutually exclusive with `--file` 遞迴上傳整個目錄並保留相對結構，與 `--file` 互斥 |
| `--file` | (none) | File to upload; repeatable. Relative paths keep their directory layout (e.g. `assets/main.js` is served as `assets/main.js`); absolute paths upload as the bare file name. Provide `--file` or `--dir` 可重複；相對路徑保留目錄結構，絕對路徑只取檔名。需擇一提供 `--file` 或 `--dir` |

### apps delete

Delete an uploaded app and all its files. 刪除已上傳的應用及其所有檔案。

```bash
shioaji apps delete --name myapp
```

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | (required) | App name |

---

## data -- Market Data / 行情資料

```
shioaji data <SUBCOMMAND>
```

### data ticks

Get tick data for a contract.

```bash
shioaji data ticks --code 2330
shioaji data ticks --code 2330 --date 2024-01-15 --last 50
shioaji data ticks --code 2330 --all
shioaji data ticks --code TXFR1 --security-type FUT --exchange TAIFEX
```

| Flag | Default | Description |
|------|---------|-------------|
| `--code` | (required) | Security code (e.g. 2330, TXFR1) |
| `--date` | today | Trading date (YYYY-MM-DD) |
| `--last` | 10 | Number of last ticks to return |
| `--all` | false | Fetch all ticks for the day (overrides --last) |
| `--security-type` | STK | Security type: STK, FUT, OPT, IND |
| `--exchange` | TSE | Exchange: TSE, OTC, TAIFEX |

### data kbars

Get K-bar (OHLCV) data for a contract.

```bash
shioaji data kbars --code 2330
shioaji data kbars --code 2330 --start 2024-01-01 --end 2024-01-31
```

| Flag | Default | Description |
|------|---------|-------------|
| `--code` | (required) | Security code |
| `--start` | today | Start date (YYYY-MM-DD) |
| `--end` | today | End date (YYYY-MM-DD) |
| `--security-type` | STK | Security type: STK, FUT, OPT, IND |
| `--exchange` | TSE | Exchange: TSE, OTC, TAIFEX |

### data scanner

Get scanner ranking data.

```bash
shioaji data scanner
shioaji data scanner --scanner-type volume-rank --count 20 --ascending
```

| Flag | Default | Description |
|------|---------|-------------|
| `--scanner-type` | change-percent-rank | One of: change-percent-rank, change-price-rank, day-range-rank, volume-rank, amount-rank, tick-count-rank |
| `--date` | today | Trading date (YYYY-MM-DD) |
| `--ascending` | false | Sort ascending |
| `--count` | 50 | Number of results |

### data stream

Stream real-time market data via SSE. Press Ctrl+C to stop.

```bash
shioaji data stream --code 2330
shioaji data stream --code 2330 --quote-type bid_ask
shioaji data stream --code TXFR1 --security-type FUT --quote-type quote
shioaji data stream --code 2330 --intraday-odd
```

| Flag | Default | Description |
|------|---------|-------------|
| `--code` | (required) | Security code |
| `--quote-type` | tick | Quote type: tick, bid_ask, quote |
| `--security-type` | STK | Security type: STK, FUT, OPT, IND |
| `--intraday-odd` | false | Include intraday odd lot trades |

The CLI resolves the contract code, subscribes to the appropriate SSE endpoint, streams data lines to stdout, and unsubscribes on exit.

For continuous-month futures such as `TXFR1` / `TXFR2`, the CLI resolves the contract first and forwards the contract `target_code` when subscribing. CLI users should pass `--code TXFR1 --security-type FUT`; HTTP clients must include `target_code` themselves when the resolved contract requires it.

### data snapshots

Get snapshots for multiple contracts.

```bash
shioaji data snapshots --codes 2330,2317,2454
shioaji data snapshots --codes TXFR1,MXFR1 --security-type FUT --exchange TAIFEX
```

| Flag | Default | Description |
|------|---------|-------------|
| `--codes` | (required) | Comma-separated security codes |
| `--security-type` | STK | Security type: STK, FUT, OPT, IND |
| `--exchange` | TSE | Exchange: TSE, OTC, TAIFEX |

### data daily-quotes

Get daily quotes (OHLCV) for the whole market. 取得全市場每日行情（開高低收量）。

```bash
shioaji data daily-quotes
shioaji data daily-quotes --date 2024-01-16
shioaji data daily-quotes --date 2024-01-16
shioaji data daily-quotes --exclude-warrant=false   # include warrants 含權證
shioaji data daily-quotes -f json
```

| Flag | Default | Description |
|------|---------|-------------|
| `--date` | today | Trading date (YYYY-MM-DD) 交易日 |
| `--exclude-warrant` | true | Exclude warrants from the result (pass `--exclude-warrant=false` to include them) 排除權證（`--exclude-warrant=false` 可包含權證） |

JSON output follows the HTTP `DailyQuotes` column-oriented schema (`Date`, `Code`, `Open`, `High`, `Low`, `Close`, `Volume`, `Transaction`, `Amount` vectors); non-JSON formats transpose to per-stock rows.
JSON 輸出沿用 HTTP `DailyQuotes` 欄位導向格式；非 JSON 格式會轉置為逐檔列。

### data credit-enquire

Get credit enquire (margin/short remaining) for contracts. 查詢合約的融資融券餘額。

```bash
shioaji data credit-enquire --codes 2330,2890
shioaji data credit-enquire --codes 2330 -f json
```

| Flag | Default | Description |
|------|---------|-------------|
| `--codes` | (required) | Comma-separated security codes 逗號分隔的證券代碼 |
| `--security-type` | STK | Security type: STK, FUT, OPT, IND |
| `--exchange` | TSE | Exchange: TSE, OTC, TAIFEX |

### data short-stock-sources

Get short stock sources (borrowable shares) for contracts. 查詢合約的可借券數量（券源）。

```bash
shioaji data short-stock-sources --codes 2330,2317
shioaji data short-stock-sources --codes 2330 -f json
```

| Flag | Default | Description |
|------|---------|-------------|
| `--codes` | (required) | Comma-separated security codes 逗號分隔的證券代碼 |
| `--security-type` | STK | Security type: STK, FUT, OPT, IND |
| `--exchange` | TSE | Exchange: TSE, OTC, TAIFEX |

### data regulatory

Get regulatory disposition (處置股) or attention (注意股) stock data. One command serves both lists; `--type` selects the endpoint.
查詢處置股或注意股清單。單一指令以 `--type` 切換端點。

```bash
shioaji data regulatory                  # disposition stocks (default) 處置股（預設）
shioaji data regulatory --type punish    # disposition stocks 處置股
shioaji data regulatory --type notice    # attention stocks 注意股
shioaji data regulatory --type notice -f json
```

| Flag | Default | Description |
|------|---------|-------------|
| `--type` | punish | Regulatory data type: `punish` (處置股) or `notice` (注意股) |

JSON output follows the HTTP `PunishResp` / `NoticeResp` column-oriented schemas; non-JSON formats transpose to per-stock rows.
JSON 輸出沿用 HTTP `PunishResp` / `NoticeResp` 欄位導向格式；非 JSON 格式會轉置為逐檔列。

---

## order -- Order Management / 委託管理

```
shioaji order <SUBCOMMAND>
```

### order place

Place a stock or futures order. The CLI resolves the contract, then dispatches to the appropriate order type (stock or futures) based on security type.

For continuous-month futures such as `TXFR1` / `TXFR2`, the CLI preserves the resolved contract `target_code` before placing the order. CLI users do not pass `target_code` manually; direct HTTP clients should include it for those futures aliases.

`--account` is optional. Omit it to use the default signed account of the matching type (stock account for STK contracts, futures account for FUT/OPT). Pass `BROKER_ID-ACCOUNT_ID` to target a specific account; the server fills in the remaining fields (`person_id`, `signed`, `username`) from the login session in supported 1.5.x versions.

```bash
## Order examples are disabled by default.
## Confirm simulation/production mode, account, payload, response status,
## and order-event handling in ORDERS.md before enabling.

# Buy 1 lot of TSMC at limit price 600 (default stock account)
# shioaji order place --code 2330 --action Buy --price 600 --quantity 1

# Market sell order for futures
# shioaji order place --code TXFR1 --action Sell --quantity 1 --price-type mkt --security-type FUT

# Place without waiting for order event confirmation
# shioaji order place --code 2330 --action Buy --price 600 --quantity 1 --no-wait

# Target a specific account
# shioaji order place --code 2330 --action Buy --price 600 --quantity 1 --account 9A95-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--code` | (required) | Security code (e.g. 2330, TXFR1) |
| `--action` | (required) | Buy or Sell |
| `--price` | 0 | Order price (0 for market orders) |
| `--quantity` | (required) | Order quantity |
| `--price-type` | lmt | Price type: lmt, mkt (stock); lmt, mkt, mkp (futures) |
| `--order-type` | rod | Order type: rod, ioc, fok |
| `--order-lot` | (none) | Stock order lot type (e.g. Common, Odd, etc.) |
| `--order-cond` | (none) | Stock order condition |
| `--octype` | (none) | Futures open/close type |
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format |
| `--security-type` | STK | Security type hint for contract lookup |
| `--no-wait` | false | Skip waiting for order events after placing |

By default, after placing an order the CLI connects to the order event SSE stream and waits up to 30 seconds for confirmation. Use `--no-wait` to skip.

### order cancel

Cancel an order by trade ID.

```bash
shioaji order cancel --id abc123
shioaji order cancel --id abc123 --no-wait
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Trade ID |
| `--no-wait` | false | Skip waiting for order events |

### order list

List all trades. Without `--account` fetches the default stock and futures accounts (mirrors original shioaji behaviour). Pass `--account` to fetch a specific non-default account — this also runs `update_status` on that account so subsequent `update-price` / `update-qty` / `cancel` calls can find the trade in cache.

```bash
shioaji order list
shioaji order list -f json
shioaji order list --account 9A95-9816502
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (default stock account + default futures account) | Account in `BROKER_ID-ACCOUNT_ID` format. Required to surface trades placed on non-default accounts. |

### order update-price

Update an order's price by trade ID.

```bash
shioaji order update-price --id abc123 --price 605
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Trade ID |
| `--price` | (required) | New price |
| `--no-wait` | false | Skip waiting for order events |

### order update-qty

Update an order's quantity by trade ID.

```bash
shioaji order update-qty --id abc123 --quantity 2
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Trade ID |
| `--quantity` | (required) | New quantity |
| `--no-wait` | false | Skip waiting for order events |

### order events

Stream real-time order and deal events via SSE. Press Ctrl+C to stop.

```bash
shioaji order events
```

Displays all order/deal events (stock orders, stock deals, futures orders, futures deals) as they arrive.

---

## portfolio -- Portfolio Queries / 投資組合查詢

```
shioaji portfolio <SUBCOMMAND>
```

### portfolio balance

Get account balance (stock account).

```bash
shioaji portfolio balance
shioaji portfolio balance --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format (e.g. 9A00-1234567) |

### portfolio positions

Get positions.

```bash
shioaji portfolio positions
shioaji portfolio positions --account-type F
shioaji portfolio positions --unit share
shioaji portfolio positions --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format |
| `--unit` | common | Unit: common or share |

### portfolio margin

Get margin info (futures account).

```bash
shioaji portfolio margin
shioaji portfolio margin --account F002000-7654321
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format (e.g. F002000-7654321) |

### portfolio position-detail

Get position detail by detail id (the `id` field from `portfolio positions`).
依持倉明細編號查詢部位明細（`id` 取自 `portfolio positions` 的回傳）。

```bash
shioaji portfolio position-detail --detail-id 0
shioaji portfolio position-detail --detail-id 0 --account-type F
shioaji portfolio position-detail --detail-id 0 --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--detail-id` | (required) | Detail ID from `portfolio positions` |
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format |

### portfolio profit-loss

Get realized profit and loss for a date range.
查詢區間已實現損益。

```bash
shioaji portfolio profit-loss
shioaji portfolio profit-loss --begin-date 2026-06-01 --end-date 2026-06-10
shioaji portfolio profit-loss --account-type F
shioaji portfolio profit-loss --unit share --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format |
| `--begin-date` | today | Begin date (YYYY-MM-DD) |
| `--end-date` | today | End date (YYYY-MM-DD) |
| `--unit` | common | Unit: common or share |

### portfolio profit-loss-detail

Get realized profit and loss detail by detail id (the `id` field from `portfolio profit-loss`).
依損益明細編號查詢已實現損益明細（`id` 取自 `portfolio profit-loss` 的回傳）。

```bash
shioaji portfolio profit-loss-detail --detail-id 0
shioaji portfolio profit-loss-detail --detail-id 0 --unit share
shioaji portfolio profit-loss-detail --detail-id 0 --account-type F
```

| Flag | Default | Description |
|------|---------|-------------|
| `--detail-id` | (required) | Detail ID from `portfolio profit-loss` |
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format |
| `--unit` | common | Unit: common or share |

### portfolio profit-loss-summary

Get profit and loss summary for a date range.
查詢區間損益彙總。

```bash
shioaji portfolio profit-loss-summary
shioaji portfolio profit-loss-summary --begin-date 2026-06-01 --end-date 2026-06-10
shioaji portfolio profit-loss-summary --account-type F
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account-type` | S | Account type: S (stock) or F (futures) |
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format |
| `--begin-date` | today | Begin date (YYYY-MM-DD) |
| `--end-date` | today | End date (YYYY-MM-DD) |

### portfolio trading-limits

Get trading limits (stock account).
查詢股票帳戶交易額度。

```bash
shioaji portfolio trading-limits
shioaji portfolio trading-limits --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format (e.g. 9A00-1234567) |

### portfolio settlements

Get the settlement list (date / amount / T offset rows, stock account). Uses `POST /api/v1/portfolio/settlements`; the legacy single T/T+1/T+2 endpoint is intentionally not exposed.
查詢交割列表（date / amount / T 偏移列，股票帳戶）。使用 `POST /api/v1/portfolio/settlements`；舊版單一 T/T+1/T+2 端點刻意不提供 CLI。

```bash
shioaji portfolio settlements
shioaji portfolio settlements --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (none) | Account in BROKER_ID-ACCOUNT_ID format (e.g. 9A00-1234567) |

---

## reserve -- Stock Reserve & Earmarking / 股票預收券款

```
shioaji reserve <SUBCOMMAND>
```

Stock reserve (預收股票) and earmarking (預收款項) operations for disposition/attention/warning stocks. All subcommands operate on the stock account; `--account` is optional and defaults to the default stock account. See [RESERVE.md](RESERVE.md) for response payload shapes and decision guidance.

預收券款指令群組，適用於處置股、注意股或警示股。所有子指令皆使用股票帳戶；`--account` 為選填，預設使用預設股票帳戶。回應欄位與判讀方式詳見 [RESERVE.md](RESERVE.md)。

> **Note 注意**: `reserve stock` and `reserve earmarking` submit real reserve requests in production. Check `status` and `info` in the response — HTTP 200 alone does not mean the reserve succeeded. Simulation mode returns default/empty values.
>
> `reserve stock` 與 `reserve earmarking` 在正式環境會送出真實預收申請。請檢查回應中的 `status` 與 `info` —— 僅 HTTP 200 不代表預收成功。模擬環境回傳預設／空值。

### reserve summary

Get the stock reserve summary: which stocks are available for reserve and how many shares are already reserved.
取得預收券款摘要：哪些股票可預收以及已預收股數。

```bash
shioaji reserve summary
shioaji reserve summary --account 9A00-1234567
shioaji reserve summary -f json
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (default stock account) | Account in BROKER_ID-ACCOUNT_ID format (e.g. 9A00-1234567) |

### reserve detail

Get the stock reserve detail: records of already-reserved stocks with per-row `status` / `info`.
取得預收券款明細：已預收股票記錄，每筆含 `status` / `info`。

```bash
shioaji reserve detail
shioaji reserve detail --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (default stock account) | Account in BROKER_ID-ACCOUNT_ID format |

### reserve stock

Place a stock reserve request (reserve shares for a disposition stock). The CLI resolves the contract from the code.
送出預收股票申請（為處置股預收股數）。CLI 會依代碼解析合約。

```bash
# Reserve 1000 shares of 2890 預收 2890 共 1000 股
shioaji reserve stock --code 2890 --share 1000

# Target a specific account 指定帳戶
shioaji reserve stock --code 2890 --share 1000 --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--code` | (required) | Stock code (e.g. 2890) |
| `--share` | (required) | Number of shares to reserve 預收股數 |
| `--account` | (default stock account) | Account in BROKER_ID-ACCOUNT_ID format |

### reserve earmarking-detail

Get earmarking (cash pre-payment) detail records.
取得預收款項（現金預付）記錄明細。

```bash
shioaji reserve earmarking-detail
shioaji reserve earmarking-detail --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--account` | (default stock account) | Account in BROKER_ID-ACCOUNT_ID format |

### reserve earmarking

Place an earmarking request (pre-pay cash before buying a disposition stock).
送出預收款項申請（買進處置股前預付現金）。

```bash
# Earmark 1000 shares of 2890 at 15.15 per share 預收 2890 共 1000 股、每股 15.15
shioaji reserve earmarking --code 2890 --share 1000 --price 15.15

# Target a specific account 指定帳戶
shioaji reserve earmarking --code 2890 --share 1000 --price 15.15 --account 9A00-1234567
```

| Flag | Default | Description |
|------|---------|-------------|
| `--code` | (required) | Stock code (e.g. 2890) |
| `--share` | (required) | Number of shares 預收股數 |
| `--price` | (required) | Price per share 每股價格 |
| `--account` | (default stock account) | Account in BROKER_ID-ACCOUNT_ID format |

---

## watchlist -- Watchlist Management / 自選股管理

```
shioaji watchlist <SUBCOMMAND>
```

Manage saved watchlists (自選股清單) through the daemon's watchlist HTTP API. All commands return the full `Watchlist` object(s); see [WATCHLIST.md](WATCHLIST.md) for response shapes and agent decision guidance.

For `--codes`, the CLI resolves each code via the contract lookup endpoint, so the correct exchange (TSE/OTC/TAIFEX) and `target_code` for continuous futures like `TXFR1` are filled in automatically. With `--security-type STK` (the default), the lookup falls back to FUT/OPT/IND when no stock matches; `FUT`, `OPT`, or `IND` searches only that type.
`--codes` 中的每個代碼會先經由合約查詢端點解析，自動帶入正確的交易所（TSE/OTC/TAIFEX）以及連續月期貨（如 `TXFR1`）的 `target_code`。`--security-type STK`（預設值）查無股票時會回退嘗試 FUT/OPT/IND；指定 `FUT`、`OPT`、`IND` 則只查該類型。

### watchlist list

List all watchlists. 取得所有自選股清單。

```bash
shioaji watchlist list
shioaji watchlist list -f json
```

Maps to `GET /api/v1/watchlist`.

### watchlist create

Create a new watchlist, optionally with initial contracts. 建立新清單，可同時加入初始合約。

```bash
shioaji watchlist create --name "My Watchlist"
shioaji watchlist create --name "Tech" --codes 2330,2317
shioaji watchlist create --name "Futures" --codes TXFR1 --security-type FUT
```

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | (required) | Watchlist name |
| `--codes` | (none) | Comma-separated security codes for initial contracts |
| `--security-type` | STK | Security type hint for contract lookup: STK, FUT, OPT, IND |

Maps to `POST /api/v1/watchlist`. The response contains the created `id`; use it for subsequent commands.

### watchlist show

Show a single watchlist by ID. 依 ID 取得單一清單。

```bash
shioaji watchlist show --id wl-1
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Watchlist ID |

Maps to `GET /api/v1/watchlist/{id}`.

### watchlist sync

Replace **ALL** contracts in a watchlist with the given codes. 以指定代碼**覆蓋**清單中的所有合約。

```bash
shioaji watchlist sync --id wl-1 --codes 2330,2454
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Watchlist ID |
| `--codes` | (required) | Comma-separated security codes (replaces all existing contracts) |
| `--security-type` | STK | Security type hint for contract lookup: STK, FUT, OPT, IND |

Maps to `PUT /api/v1/watchlist/{id}`. Use only when overwrite is intended; for append/remove use `add` / `remove`.
僅在確定要覆蓋時使用；要追加或移除請改用 `add` / `remove`。

### watchlist delete

Delete a watchlist by ID. 依 ID 刪除清單。

```bash
shioaji watchlist delete --id wl-1
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Watchlist ID |

Maps to `DELETE /api/v1/watchlist/{id}`. The response is the deleted watchlist object.

### watchlist add

Add contracts to a watchlist. 新增合約至清單。

```bash
shioaji watchlist add --id wl-1 --codes 2330,2317
shioaji watchlist add --id wl-1 --codes TXFR1 --security-type FUT
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Watchlist ID |
| `--codes` | (required) | Comma-separated security codes to add |
| `--security-type` | STK | Security type hint for contract lookup: STK, FUT, OPT, IND |

Maps to `POST /api/v1/watchlist/{id}/contracts`. The response is the updated watchlist.

### watchlist remove

Remove contracts from a watchlist. 從清單移除合約。

```bash
shioaji watchlist remove --id wl-1 --codes 2330
```

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | (required) | Watchlist ID |
| `--codes` | (required) | Comma-separated security codes to remove |
| `--security-type` | STK | Security type hint for contract lookup: STK, FUT, OPT, IND |

Maps to `DELETE /api/v1/watchlist/{id}/contracts`. The response is the updated watchlist.

---

## utils -- Utility Commands / 工具指令

```
shioaji utils <SUBCOMMAND>
```

### utils token -- Token Pool Management / Token Pool 管理

```
shioaji utils token [-k <KEY>] [-s <SECRET>] <SUBCOMMAND>
```

The token subcommand family manages the local token pool (10 slots). Many subcommands require API key and secret for decryption.

| Flag | Short | Description |
|------|-------|-------------|
| `--key` | `-k` | API key for decryption |
| `--secret` | `-s` | Secret key for decryption |

#### utils token list

List all token slots.

```bash
shioaji utils token list
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY list
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY list --detailed
```

| Flag | Description |
|------|-------------|
| `--detailed` / `-d` | Show detailed information (process, heartbeat, client name) |

#### utils token show

Show token details for one or all slots. Requires `-k` and `-s`.

```bash
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY show --all
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY show --slot 3
```

| Flag | Description |
|------|-------------|
| `--all` | Show all tokens (conflicts with --slot) |
| `--slot` | Show specific slot number (1-10, conflicts with --all) |

#### utils token status

Show token pool status summary (counts of active, available, expired, empty slots).

```bash
shioaji utils token status
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY status
```

#### utils token clean

Clean expired or invalid tokens from the pool.

```bash
# Clean expired tokens (default)
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY clean

# Dry run -- show what would be cleaned
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY clean --dry-run

# Clean all tokens (with server logout)
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY clean --all

# Clean a specific slot
shioaji utils token -k $SJ_API_KEY -s $SJ_SEC_KEY clean --slot 5
```

| Flag | Description |
|------|-------------|
| `--dry-run` | Only show what would be cleaned, no changes |
| `--all` | Remove all tokens (calls logout on server first; conflicts with --slot) |
| `--slot` | Clean specific slot 1-10 (conflicts with --all) |

### utils api -- API Connectivity / API 連線

```
shioaji utils api <SUBCOMMAND>
```

#### utils api check

Check direct API connectivity and authentication (bypasses daemon, connects directly to Shioaji servers).

```bash
shioaji utils api check
shioaji utils api check --production
```

| Flag | Description |
|------|-------------|
| `--production` / `--prod` | Run in production mode (default: simulation). Also settable via `SJ_PRODUCTION` env var |

---

## tree -- Show Command Tree / 顯示指令樹

Display the full command tree structure.

```bash
shioaji tree
shioaji tree --params       # Show parameters
shioaji tree --all          # Show descriptions and parameters
```

| Flag | Short | Description |
|------|-------|-------------|
| `--params` | `-p` | Show parameters for each command |
| `--all` | `-a` | Show descriptions and parameters |

---

## completions -- Shell Completions / Shell 自動完成

Generate shell completion scripts.

```bash
shioaji completions zsh
shioaji completions bash
shioaji completions fish
shioaji completions powershell
```

### Installation / 安裝

| Shell | Install Command |
|-------|-----------------|
| Zsh | `shioaji completions zsh > ~/.zfunc/_shioaji` |
| Bash | `shioaji completions bash > /etc/bash_completion.d/shioaji` |
| Fish | `shioaji completions fish > ~/.config/fish/completions/shioaji.fish` |
| PowerShell | `shioaji completions powershell > _shioaji.ps1` |

---

## version -- Print Version / 顯示版本

Print the installed CLI version. Available in two forms:

### `--version` flag (clap built-in)

```bash
shioaji --version
shioaji -V
# → shioaji 1.5.9
```

### `version` subcommand (structured output)

Goes through the global `--format` mechanism (default `toon`), so it can
be parsed in scripts:

```bash
shioaji version
# → name: shioaji
#   version: "1.5.9"

shioaji version --format json
# → {"name":"shioaji","version":"1.5.9"}

shioaji version --format human
# → name: shioaji
#   version: "1.5.9"
```

Use the flag for a one-liner, the subcommand when you need machine-readable output (e.g. CI pipelines that pin a minimum CLI version).

---

## Daemon Architecture / 背景服務架構

The CLI operates in a **daemon-client** architecture:

1. **Auto-start**: When any data-path command is executed (`auth`, `apps`, `data`, `order`, `portfolio`, `reserve`, `watchlist`), the CLI calls `ensure_daemon()`. If no daemon is running, one is spawned automatically.
2. **Communication**: The CLI client (`DaemonClient`) sends HTTP requests to the daemon, preferring UDS on Unix for localhost connections, falling back to TCP.
3. **Lifecycle**:
   - `shioaji server start` -- explicitly start the daemon (foreground)
   - `shioaji server status` -- check if daemon is running (PID, port, health)
   - `shioaji server stop` -- send stop signal to the daemon
   - `shioaji server check` -- verify connectivity and auth against running daemon
4. **PID files**: Stored in the session directory at `server-{port}.pid`
5. **Health checks**: The daemon exposes `/api/v1/health` (public, no auth required)

---

## UDS Support / Unix Domain Socket 支援

On Unix systems, the server binds to both TCP and a Unix domain socket simultaneously:

- **Default socket path**: `~/.shioaji/sessions/server-{port}.sock`
- **Custom path**: Set `SJ_UDS_PATH` environment variable
- **Disable**: Set `SJ_UDS_DISABLE=true`
- **Permissions**: Socket file created with mode `0600` (owner-only)
- **Stale detection**: On startup, the server checks if an existing socket file is stale (ConnectionRefused = stale, remove; connected = live, leave)

The CLI client (`DaemonClient`) automatically prefers UDS when available, falling back to TCP.
