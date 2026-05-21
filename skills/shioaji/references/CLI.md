# Shioaji CLI Command Reference / Shioaji CLI 指令參考

> Canonical inventory of every `shioaji` CLI command, generated from source.
> Source of truth: `src/cli/mod.rs`, `src/cli/commands/`, `src/cli/utils/`, `src/cli/output.rs`

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
8. [data -- Market Data / 行情資料](#data----market-data--行情資料)
   - [data ticks](#data-ticks)
   - [data kbars](#data-kbars)
   - [data scanner](#data-scanner)
   - [data stream](#data-stream)
   - [data snapshots](#data-snapshots)
9. [order -- Order Management / 委託管理](#order----order-management--委託管理)
   - [order place](#order-place)
   - [order cancel](#order-cancel)
   - [order list](#order-list)
   - [order update-price](#order-update-price)
   - [order update-qty](#order-update-qty)
   - [order events](#order-events)
10. [portfolio -- Portfolio Queries / 投資組合查詢](#portfolio----portfolio-queries--投資組合查詢)
    - [portfolio balance](#portfolio-balance)
    - [portfolio positions](#portfolio-positions)
    - [portfolio margin](#portfolio-margin)
11. [utils -- Utility Commands / 工具指令](#utils----utility-commands--工具指令)
    - [utils token list](#utils-token-list)
    - [utils token show](#utils-token-show)
    - [utils token status](#utils-token-status)
    - [utils token clean](#utils-token-clean)
    - [utils api check](#utils-api-check)
12. [tree -- Show Command Tree / 顯示指令樹](#tree----show-command-tree--顯示指令樹)
13. [completions -- Shell Completions / Shell 自動完成](#completions----shell-completions--shell-自動完成)
14. [version -- Print Version / 顯示版本](#version----print-version--顯示版本)
15. [Daemon Architecture / 背景服務架構](#daemon-architecture--背景服務架構)
16. [UDS Support / Unix Domain Socket 支援](#uds-support--unix-domain-socket-支援)

---

## Overview / 概覽

The `shioaji` binary is a single CLI that doubles as:
- **A command-line client** for querying market data, placing orders, and managing portfolios.
- **A daemon server** (`shioaji server start`) that hosts the HTTP API.

All data-path commands (`auth`, `data`, `order`, `portfolio`) communicate with the daemon via HTTP (preferring UDS on Unix). If no daemon is running, the CLI auto-starts one (`ensure_daemon`).

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
│   ├── start       [--production]
│   ├── check
│   ├── status
│   └── stop
├── auth
│   ├── accounts
│   └── usage
├── data
│   ├── ticks       --code <CODE> [--date] [--last 10] [--all] [--security-type STK] [--exchange TSE]
│   ├── kbars       --code <CODE> [--start] [--end] [--security-type STK] [--exchange TSE]
│   ├── scanner     [--scanner-type change-percent-rank] [--date] [--ascending] [--count 50]
│   ├── stream      --code <CODE> [--quote-type tick] [--security-type STK] [--intraday-odd]
│   └── snapshots   --codes <CODES> [--security-type STK] [--exchange TSE]
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
│   └── margin      [--account]
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

### server start

Start the API server (daemon). Authenticates with SJ_API_KEY/SJ_SEC_KEY and begins serving HTTP.

```bash
shioaji server start
shioaji server start --production
shioaji server start --prod        # visible alias
```

| Flag | Description |
|------|-------------|
| `--production` / `--prod` | Run in production mode (default: simulation). Also settable via `SJ_PRODUCTION` env var |

### server check

Check server connectivity and authentication. Sends a health check to the running daemon.

```bash
shioaji server check
```

### server status

Show daemon status (running, PID, port, health, simulation mode).

```bash
shioaji server status
```

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

---

## order -- Order Management / 委託管理

```
shioaji order <SUBCOMMAND>
```

### order place

Place a stock or futures order. The CLI resolves the contract, then dispatches to the appropriate order type (stock or futures) based on security type.

`--account` is optional. Omit it to use the default signed account of the matching type (stock account for STK contracts, futures account for FUT/OPT). Pass `BROKER_ID-ACCOUNT_ID` to target a specific account; the server fills in the remaining fields (`person_id`, `signed`, `username`) from the login session (1.5.12+, [#234](https://github.com/Yvictor/rshioaji/issues/234)).

```bash
# Buy 1 lot of TSMC at limit price 600 (default stock account)
shioaji order place --code 2330 --action Buy --price 600 --quantity 1

# Market sell order for futures
shioaji order place --code TXFR1 --action Sell --quantity 1 --price-type mkt --security-type FUT

# Place without waiting for order event confirmation
shioaji order place --code 2330 --action Buy --price 600 --quantity 1 --no-wait

# Target a specific account
shioaji order place --code 2330 --action Buy --price 600 --quantity 1 --account 9A95-1234567
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

1. **Auto-start**: When any data-path command is executed (`auth`, `data`, `order`, `portfolio`), the CLI calls `ensure_daemon()`. If no daemon is running, one is spawned automatically.
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
