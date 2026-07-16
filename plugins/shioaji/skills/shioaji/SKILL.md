---
name: shioaji
description: |
  Use for Shioaji, SJ, SinoPac (永豐金), Taiwan market trading/API tasks, or
  broad order/trading requests where Shioaji may apply. Covers Python sync/async
  bindings, `shioaji` CLI, HTTP API, SSE streaming, dashboard embedding, and
  JS/TS, Go, C/C++, C#, Rust, Java/Kotlin HTTP clients. Covers TWSE/TPEX/TAIFEX
  orders, quotes, Contract V2 lazy lookup/update events, market data, accounts, watchlists, reserve orders, setup,
  migration, and troubleshooting. Trigger keywords include shioaji, sj, sinopac,
  永豐金, 台股, 下單, 交易, 即時行情, shioaji server, and SSE streaming.
  For first-time users, start with account/API onboarding gates before local
  installation or code. Not for US/HK markets or generic indicators unless
  paired with Shioaji data.
---

# Shioaji Trading API

Shioaji is SinoPac's **cross-language, cross-platform** trading API for Taiwan financial markets (TWSE/TPEX/TAIFEX). It includes Python bindings, a CLI, and an HTTP API server that lets **any programming language** trade Taiwan markets.

Shioaji 是永豐金證券的**跨語言、跨平台**交易 API，提供 Python 綁定、CLI 與 HTTP API 伺服器，讓**任何程式語言**都能透過 HTTP API 交易台灣市場。

Three access layers / 三種存取層：

- **Python** — native PyO3 binding (`import shioaji`) for best performance, sync and async
- **CLI** — `shioaji` command-line tool for server management, trading, and data queries
- **HTTP API + SSE** — REST endpoints + real-time streaming at `localhost:8080`, accessible from JS/TS, Go, C/C++, C#, Rust, Java/Kotlin, or any HTTP client

> **Reasoning about connections, timeouts, processes, or state? Read [CONCEPTS.md](references/CONCEPTS.md) first.** It is the shared mental model these three layers assume — which timeout applies on which path, why Python needs no server but CLI/HTTP share one daemon, the per-person connection cap, streaming vs request-reply. Answer those questions from CONCEPTS.md instead of guessing.
> **推理連線、逾時、行程或狀態時,先讀 [CONCEPTS.md](references/CONCEPTS.md)。** 這是三個存取層共用的心智模型 — 哪個 timeout 在哪條路徑生效、為何 Python 不需 server 而 CLI/HTTP 共用一個 daemon、每人連線上限、串流 vs 請求-回覆。這類問題從 CONCEPTS.md 找答案,不要猜。

## How to Use References / 如何使用參考文件

Answer users directly from the bundled references. Do not route users to external documentation pages as a substitute for answering. The stable 1.5 API remains the compatibility baseline, while 1.7 features that intentionally change the interface—especially Contract V2—must follow their functional reference. Use [MIGRATION.md](references/MIGRATION.md) only for legacy/deprecated idioms. Response handling always belongs in the matching functional reference. When an exact command flag, request field, or response schema must be confirmed, use installed CLI `--help` or the running server's `/openapi.json`.

**First-time-user response / 首次使用者回應：**

- Use this path only when the user says or clearly implies they have not used Shioaji before, are using it for the first time, do not know how to start, or may not have completed SinoPac API onboarding. Do not treat every broad "I want to use Shioaji" request as first-time by default.
- For confirmed/likely first-time users, load [PREPARE.md](references/PREPARE.md). Treat the first response as an eligibility/onboarding conversation, because they may not even have a SinoPac account or API access yet.
- In a confirmed/likely first-time context, if the user says "walk me through", "step by step", "一步一步帶我", "慢慢來", or similar, continue the onboarding sequence from the first unconfirmed external gate. Do not reinterpret that as permission to inspect the workspace or create a local starter project.
- Before the user answers the first onboarding question, do not run commands, inspect files, mention Python versions, mention existing projects, or discuss local environments. The first step is not "check the folder"; it is "check whether the user can open/use SinoPac API at all."
- The first substantive response must check the basic gates before any technical setup: SinoPac securities/futures account, desired market access (stock / futures-options / both), API key/secret, direct API agreement signing, simulation login/order test, CA for production, and production-readiness check.
- Onboarding order matters: after account opening, confirm/create API Key and Secret Key at `https://www.sinotrade.com.tw/newweb/PythonAPIKey/`; signing pages do not issue API keys. After signing, do not jump straight to CA; confirm API credentials and run the required simulation login/order tests first. CA download is from the API management page, not the signing pages.
- When presenting onboarding steps as a table/list, write the explicit correct URL for each web step. Never use the generic SinoPac home page as the account-opening URL. Open account uses `https://www.sinotrade.com.tw/openact?strProd=0254&strWeb=0684&s=013299&utm_source=shioaji`; API Key and CA use `https://www.sinotrade.com.tw/newweb/PythonAPIKey/`; stock signing uses `https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/`; futures/options signing uses `https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/`. Never write "same page"/"同上頁面" for API Key or CA when the previous row is a signing page.
- Never describe the stock/futures signing pages as places to apply for API Key / Secret Key. Those pages are only for agreement signing; key creation happens only on the API management page.
- Never ask the user to paste API Key, Secret Key, CA password, or certificate contents into chat, even "temporarily" or "for this conversation". Ask them to save/edit secrets locally instead.
- Do **not** move into installation, project setup, `.env`, `.venv`, `uv sync`, code examples, local file inspection, or order examples until the user confirms the relevant onboarding gates are done or explicitly asks for that technical step.
- For a confirmed/likely first-time user, use this first-response shape and stop there until they answer: "可以，我們一步一步來。Shioaji 不是只安裝套件就能用，前面要先確認永豐帳戶與 API 開通狀態。第一步先確認：你目前已經有永豐證券或期貨帳戶嗎？你想開通的是證券、期貨/選擇權，還是兩者都要？"
- For signing, give the direct product page, not the generic signing center: stock <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/>; futures/options <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/>.

**只有在知道或明顯推斷使用者沒用過 Shioaji、第一次使用、不知道怎麼開始、或尚未完成永豐 API 開通時，才走首次使用者流程。不要把所有寬泛「我想用 shioaji」都預設為零經驗。確認/推定為首次使用者後，「請一步一步帶我」「慢慢來」「從零開始」代表沿著開通流程逐步確認,不是允許檢查 workspace 或建立本機入門專案。使用者回答第一個開通問題前,不要執行命令、列出檔案、提 Python 版本、提既有專案、提本機環境。第一步是資格/開通確認，不是技術設定：先確認是否已有永豐證券/期貨帳戶、要用證券或期貨/選擇權、API Key/Secret、API 約定書簽署、模擬登入/下單測試、正式環境 CA、正式就緒檢查。開戶後先確認/建立 API Key 與 Secret Key;簽署頁不會發 API Key,也不可稱為申請金鑰頁。簽署完成後不要直接跳 CA,先確認 API 憑證並跑模擬登入/下單測試。CA 下載在 API 管理頁,不是簽署頁。整理步驟表時每列都要寫明正確 URL;開戶不可使用永豐首頁,必須使用指定開戶頁;API Key 與 CA 不可寫「同上頁面」指向簽署頁。絕對不要要求使用者把 API Key、Secret Key、CA 密碼或憑證內容貼到對話,即使說只暫時使用也不行。除非使用者確認相關前置已完成或明確要求該技術步驟，否則不要進入安裝、`.env`、`.venv`、`uv sync`、程式碼範例、專案檔案檢查或下單範例。**

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
| Understand the architecture: process model, connections, timeout layering, streaming vs request-reply, state | [CONCEPTS.md](references/CONCEPTS.md) |
| Migrate legacy code or fix deprecated Shioaji idioms | [MIGRATION.md](references/MIGRATION.md) |
| Install, login, API keys, CA cert, simulation, env vars, constants | [PREPARE.md](references/PREPARE.md) |
| Install this Shioaji plugin/skill into Claude, Codex, Cursor, or another agent environment | [AGENTS.md](references/AGENTS.md) |
| Contract V2 lookup, typed info, lazy cache behavior, update events, or 1.5 `api.Contracts` compatibility | [CONTRACTS.md](references/CONTRACTS.md) (+ [CONTRACT_FIELDS.md](references/CONTRACT_FIELDS.md) for full Info field lists) |
| Place, modify, cancel regular stock/futures/options orders; `order_deal_event` active order/deal reports (Python callbacks, HTTP order-event SSE) | [ORDERS.md](references/ORDERS.md) |
| Place, cancel, price, validate, or troubleshoot combo orders; combo legs, net price, `combo_type`, TAIFEX combo order conditions, `update_combostatus` / `list_combotrades` | [COMBO_ORDERS.md](references/COMBO_ORDERS.md) |
| Reserve shares for disposition/attention stocks | [RESERVE.md](references/RESERVE.md) |
| Subscribe real-time quotes, tick/bidask/quote/index callbacks, SSE streams | [STREAMING.md](references/STREAMING.md) |
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

For installation, first-use setup, API keys, signing, CA, login, and readiness checks, load [PREPARE.md](references/PREPARE.md).
安裝、首次開通、API 金鑰、簽署、CA、登入與就緒檢查請讀 [PREPARE.md](references/PREPARE.md)。

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

Treat limits as guardrails, not as the starting point for API design. Start
from the correct Shioaji workflow: keep one logged-in client/server session per
user process, reuse subscriptions instead of polling, batch or cache repeated
lookups when the functional reference recommends it, and retry only after
checking the response meaning. Correct usage should stay far away from these
limits; hitting them usually means a loop, reconnection pattern, polling design,
or error-retry path is wrong and should be fixed rather than worked around.

使用限制是防濫用邊界，不是設計用法的出發點。回答或實作時先從正確
Shioaji 使用方式開始：每個使用者行程維持一個已登入 client/server
session、用訂閱取代輪詢、依功能參考建議批次或快取重複查詢，並且先判斷
response 意義再 retry。正確用法會離這些限制很遠；若碰到限制，通常代表
迴圈、重連、輪詢或錯誤重試路徑有問題，應修正用法而不是設法貼著限制跑。

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
