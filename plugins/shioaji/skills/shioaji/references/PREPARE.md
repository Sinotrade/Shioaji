# Preparation 準備工作

This document covers installation, environment configuration, authentication, and common setup for the Shioaji trading API.
本文件說明 Shioaji 的安裝、環境設定、認證和常用設定。

## Table of Contents 目錄

- [Account Onboarding 開戶與開通](#account-onboarding-開戶與開通)
- [Installation 安裝](#installation-安裝)
- [Environment Variables 環境變數](#environment-variables-環境變數)
- [Login 登入](#login-登入)
- [Server Health and Auth Responses 伺服器狀態與認證回應](#server-health-and-auth-responses-伺服器狀態與認證回應)
- [Python Sync vs Async 同步與異步](#python-sync-vs-async-同步與異步)
- [Account Setup 帳戶設定](#account-setup-帳戶設定)
- [Common Constants 常用常數](#common-constants-常用常數)
- [Simulation vs Production Mode 模擬與正式模式](#simulation-vs-production-mode-模擬與正式模式)
- [CA Certificate Activation 憑證啟用](#ca-certificate-activation-憑證啟用)

---

## Account Onboarding 開戶與開通

**Before any code runs**, a brand-new user must complete SinoPac's account and API onboarding. These steps happen on SinoPac's web and desktop portals — the skill cannot do them for you. Do this once, in order; afterwards every other section in this document applies.
新使用者在執行任何程式碼前,必須先完成永豐金的開戶與 API 開通。以下步驟在永豐網站/桌面程式完成,本技能無法代勞。依序完成一次後,本文件其餘內容即可套用。

> ⚠️ There is **no single command** that performs Steps 1–4 — they are external SinoPac processes. The CLI/server only automates **Step 5** (login + CA) once your credentials and `.pfx` are in `.env`.
> 沒有任何單一指令能完成步驟 1–4(皆為永豐外部流程);CLI/伺服器只在你把金鑰與 `.pfx` 填入 `.env` 後,自動化**步驟 5**(登入 + CA)。

### Agent Prepare Playbook 代理準備劇本

When the user says or clearly implies they have not used Shioaji before, are using it for the first time, do not know how to start, or may not have completed SinoPac API onboarding, treat it as an **eligibility/onboarding workflow first**, not an install/code task, project setup task, or order task.
當使用者明講或明顯表示沒用過 Shioaji、第一次使用、不知道怎麼開始,或可能尚未完成永豐 API 開通時,請先把它當成**資格/開通流程**,而非安裝/程式碼、專案設定或下單任務。

Do not treat every broad "I want to use Shioaji" request as first-time by default. If experience/onboarding status is unknown, ask a short status question before choosing the first-time path or a technical path.
不要把所有寬泛「我想用 Shioaji」都預設為首次使用者。若經驗/開通狀態不明,先問一個簡短狀態問題,再決定走首次開通流程或技術流程。

For first-time users, do **not** lead with `pip install`, `uv add`, `uv sync`, `.env`, `.venv`, local project inspection, or a login snippet. Start by checking the external prerequisites: whether they already have a SinoPac securities/futures account, which access they need (stock / futures-options / both), whether API key/secret exist, whether the product-specific API agreement is signed, whether the simulation login/order test has passed, and whether CA/production readiness is needed.
首次使用者不要先給 `pip install`、`uv add`、`uv sync`、`.env`、`.venv`、本機專案檢查或登入範例。先確認外部前置:是否已有永豐證券/期貨帳戶、需要證券/期貨選擇權/兩者、是否已有 API Key/Secret、是否完成對應商品 API 約定書簽署、是否通過模擬登入/下單測試、是否需要 CA/正式環境就緒。

The first response should be a short prerequisite checklist plus one concrete next question. Do not proceed to technical setup until the user confirms enough prerequisites or asks for that exact step.
第一回應應是簡短前置檢查表加上一個具體下一步問題。使用者確認足夠前置條件或明確要求該步驟前,不要進入技術設定。

If a confirmed/likely first-time user asks to be guided "step by step" ("一步一步帶我", "慢慢來", "從零開始"), continue from the first unconfirmed external gate in this order: account -> market access -> API key/secret -> product-specific signing -> simulation login/order test -> CA/production readiness. Do not inspect local files, discuss `.env`/`.venv`, or create a starter project before the relevant gate is reached.
若確認/推定為首次使用者要求「一步一步帶我」「慢慢來」「從零開始」,請從第一個未確認的外部關卡開始:帳戶 -> 市場類型 -> API Key/Secret -> 對應商品簽署 -> 模擬登入/下單測試 -> CA/正式就緒。到達相關關卡前,不要檢查本機檔案、討論 `.env`/`.venv`、或建立入門專案。

Onboarding step order is strict. If the user says "I opened the account", the next gate is API Key / Secret Key creation at <https://www.sinotrade.com.tw/newweb/PythonAPIKey/>, not signing. If the user says "I signed", do not assume they received API Key / Secret Key; signing pages do not issue API credentials. After signing, confirm API credentials and proceed to simulation login/order tests. Do not jump directly to CA unless the user explicitly asks for production readiness or all earlier gates are done. CA download belongs to the API management page (<https://www.sinotrade.com.tw/newweb/PythonAPIKey/>), not the signing pages.
開通步驟順序要嚴格。使用者說「開好戶」後,下一關是到 <https://www.sinotrade.com.tw/newweb/PythonAPIKey/> 建立 API Key / Secret Key,不是簽署。使用者說「簽署好了」時,不要假設已取得 API Key / Secret Key;簽署頁不會發 API 憑證。簽署後先確認 API 憑證並進入模擬登入/下單測試。除非使用者明確要求正式就緒或前面關卡都完成,不要直接跳 CA。CA 下載在 API 管理頁(<https://www.sinotrade.com.tw/newweb/PythonAPIKey/>),不是簽署頁。

The stock/futures signing pages are **not** API Key application pages. Do not label them "證券 API Key" / "期貨 API Key", and do not tell users to apply for keys there. Use those pages only after API Key / Secret Key already exist, when the next task is agreement signing.
證券/期貨簽署頁**不是** API Key 申請頁。不要把它們標成「證券 API Key」「期貨 API Key」,也不要叫使用者去那裡申請金鑰。只有在使用者已經有 API Key / Secret Key、下一步是簽署約定書時才使用這兩個頁面。

Never ask users to paste API Key, Secret Key, CA password, or certificate contents into chat. The correct handoff is: ask them to save the Secret Key locally when it is shown, then later create a placeholder `.env` and ask them to edit it on their machine.
絕對不要要求使用者把 API Key、Secret Key、CA 密碼或憑證內容貼到對話。正確交接方式是:提醒使用者在 Secret Key 顯示當下自行保存;後續到本機設定階段時,先建立 placeholder `.env`,請使用者在本機編輯。

For account opening, use the official Shioaji campaign open-account URL: <https://www.sinotrade.com.tw/openact?strProd=0254&strWeb=0684&s=013211&utm_source=shioaji>. Do not replace it with the generic SinoPac home page (`https://www.sinotrade.com.tw/`) or a broad "SinoPac Securities" link.
開戶請使用 Shioaji 指定開戶連結: <https://www.sinotrade.com.tw/openact?strProd=0254&strWeb=0684&s=013211&utm_source=shioaji>。不要改成永豐首頁(`https://www.sinotrade.com.tw/`)或泛稱「永豐金證券」連結。

Use these step responses instead of inventing a new order:
依使用者回報狀態照下面接續,不要自己換順序:

| User says 使用者說 | Next response 下一步 |
|---|---|
| "I do not have an account yet" / 「還沒開戶」 | "第一步先開立永豐帳戶。請使用這個開戶頁: <https://www.sinotrade.com.tw/openact?strProd=0254&strWeb=0684&s=013211&utm_source=shioaji>。完成後回來告訴我「開好戶了」,我再帶你做 API Key。" |
| "I opened the account" / 「開好戶了」 | "很好,下一步是建立 API Key / Secret Key。請到 API 管理頁 <https://www.sinotrade.com.tw/newweb/PythonAPIKey/> 新增 API KEY。這一步不是去證券/期貨簽署頁。完成後請確認你已經在本機安全保存 Secret Key;不要貼到對話。" |
| "I created API Key" / 「金鑰建好了」 | "下一步是簽署對應商品的 API 約定書。證券: <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/>;期貨/選擇權: <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/>。完成後告訴我你簽了哪些商品。" |
| "I signed" / 「簽署好了」 | "很好。請先確認你已經有 API Key / Secret Key 並已安全保存。接下來是模擬登入/下單測試,不是 CA。你要建立新的入門專案,還是只在目前資料夾跑一次性測試?" |
| "Simulation test passed" / 「模擬測試通過」 | "下一步才是正式環境就緒: 需要正式權限、CA 憑證與 production login 檢查。若你只想先練習模擬,可以先停在這裡。" |
| "I need production readiness" / 「我要正式環境就緒」 | "請到 API 管理頁 <https://www.sinotrade.com.tw/newweb/PythonAPIKey/> 下載 CA 憑證,或用 eleader;不要用簽署頁下載 CA。" |

If presenting onboarding steps as a table/list, use these exact URLs and never write "same page" / "同上頁面":
若整理成開通步驟表,使用下面的明確 URL,不要寫「同上頁面」:

| Step 步驟 | URL |
|---|---|
| SinoPac account opening 開立永豐帳戶 | <https://www.sinotrade.com.tw/openact?strProd=0254&strWeb=0684&s=013211&utm_source=shioaji> |
| API Key / Secret Key creation 建立金鑰 | <https://www.sinotrade.com.tw/newweb/PythonAPIKey/> |
| Stock API signing 證券 API 簽署 | <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/> |
| Futures/options API signing 期貨/選擇權 API 簽署 | <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/> |
| CA certificate download CA 憑證下載 | <https://www.sinotrade.com.tw/newweb/PythonAPIKey/> |

Common failure pattern to avoid:
常見錯誤反例,不要這樣回:

- ❌ After "I opened the account", saying "apply for API Key at the stock/futures signing pages" or asking the user to paste API Key / Secret Key into chat.
- ✅ Correct: send only the API management page for key creation, remind them to save Secret Key locally, and stop until they confirm the key exists.

Before the user answers the first onboarding question, do not run commands, inspect files, mention Python versions, mention existing projects, or discuss local environments. Use this first response and stop: "可以，我們一步一步來。Shioaji 不是只安裝套件就能用，前面要先確認永豐帳戶與 API 開通狀態。第一步先確認：你目前已經有永豐證券或期貨帳戶嗎？你想開通的是證券、期貨/選擇權，還是兩者都要？"
使用者回答第一個開通問題前,不要執行命令、列出檔案、提 Python 版本、提既有專案、或討論本機環境。第一回應固定先問:「可以，我們一步一步來。Shioaji 不是只安裝套件就能用，前面要先確認永豐帳戶與 API 開通狀態。第一步先確認：你目前已經有永豐證券或期貨帳戶嗎？你想開通的是證券、期貨/選擇權，還是兩者都要？」

Before creating local files, ask whether the user wants a new starter project or only wants to run a one-off check in the current folder. If they choose a project, create the project and use `uv add shioaji`. If they do not want a project, do not create `pyproject.toml`; use `uvx --from shioaji shioaji ...` for CLI commands, or `uv run --with shioaji python ...` for one-off Python commands. Do not use `uv run shioaji python`.
建立本機檔案前,先問使用者要不要建立新的入門專案,或只想在目前資料夾跑一次性檢查。若要創專案,才建立專案並使用 `uv add shioaji`;若不想創專案,不要建立 `pyproject.toml`,CLI 用 `uvx --from shioaji shioaji ...`,一次性 Python 用 `uv run --with shioaji python ...`。不要使用 `uv run shioaji python`。

When running Python scripts in a uv-managed project, prefer `uv run python path/to/script.py` so the command follows the project's uv environment.
在 uv 管理的專案內執行 Python 腳本時,優先使用 `uv run python path/to/script.py`,讓指令跟著專案的 uv 環境走。

**Goal 目標** — the desired end state: 完成狀態:

- The user knows which official web pages must be completed by hand. 使用者清楚哪些官網頁面必須親自完成。
- API Key / Secret Key / CA path / CA password / production flag live in local config (`.env` or a secret store), **never pasted into chat**. 金鑰與憑證資訊存在本機設定,**絕不貼進對話**。
- Simulation login + order test have run for each requested account type. 各所需帳戶類型都已跑過模擬登入與下單測試。
- Production readiness is verified **without sending a production order**. 在**不送出正式單**的前提下確認正式環境就緒。

**Credential handoff 金鑰交接方式:**

- When local credential setup is reached, create a `.env` placeholder file for the user, then stop and ask them to edit it locally. 初次設定本機金鑰時,先幫使用者建立 `.env` placeholder,再停下來請使用者本機修改。
- The initial `.env` must contain **only** `SJ_API_KEY`, `SJ_SEC_KEY`, `SJ_CA_PATH`, `SJ_CA_PASSWD`, and `SJ_PRODUCTION`. 初始 `.env` **只放**這五個參數。
- Never ask the user to paste secrets into chat, never fill real secrets for them, and never overwrite an existing `.env`. 不要求貼密鑰、不代填真實密鑰、不覆蓋既有 `.env`。
- Ensure `.env` is ignored by git; add `.env` to `.gitignore` if needed. 確認 `.env` 不會進 git;必要時加入 `.gitignore`。

**One-command behavior 一鍵行為** — if the user says "prepare everything", run this sequence: 若使用者說「全部準備好」,依序執行:

1. Ask which market access is needed only if not inferable (stock / futures-options / both). 無法推斷時才問需要哪種市場。
2. Check local install and version — must be **≥ 1.2** for the official API test. 檢查安裝與版本(官方測試需 ≥ 1.2)。
3. Check whether credentials + CA exist in `.env` / secret store — **do not ask the user to paste secrets**. If credentials are ready but no local config exists, create a placeholder `.env` for local editing. 檢查 `.env`/secret store 是否已有金鑰與憑證,**勿要求貼上密鑰**;若憑證已申請但尚無本機設定,先建立 placeholder `.env` 讓使用者本機修改。
4. If credentials are missing, guide the user through official key creation + CA download (Steps 2 & 4). 缺金鑰就引導 Step 2、4。
5. If signing is incomplete, send the user to the direct signing page for the needed product: stock API signing <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/> or futures/options API signing <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/> (Step 3). 未簽署時直接給對應簽署頁:證券 API 簽署頁或期貨/選擇權 API 簽署頁。
6. Start in simulation and run login/account checks. 以模擬模式登入並檢查帳戶。
7. Run the simulation order test for each requested account type; keep **≥ 1 second** between stock and futures tests. 各類型跑下單測試,股/期間隔 ≥ 1 秒。
8. After login, confirm each account's `signed` field; `signed=False` ⇒ not ready for that product's production workflow. 登入後確認各帳戶 `signed`;`False` 代表該商品尚未就緒。
9. For production readiness only: verify production login + account list + contracts + CA expiry. **Do not place a production order** unless the user explicitly asks for a live trade as a separate task. 僅就緒檢查:驗證正式登入/帳戶/合約/憑證到期;**除非另外明確要求,否則不下正式單**。
10. Report a status table: **Done / Needs user action / Blocked / Not applicable**. 回報狀態表。

**Never do this 禁止事項:**

- Don't create, sign, or approve legal documents without the user reviewing the page. 不在使用者未檢視頁面下建立/簽署/同意法律文件。
- Don't bypass two-factor auth — the user completes every SMS/email/OTP step. 不繞過 2FA。
- Don't store API Key / Secret Key / CA password / certificate files / browser session state in the repo. 不把金鑰、密鑰、CA 密碼、憑證檔、瀏覽器 session 存入 repo。
- Don't send a production order as part of "prepare" or "readiness" work. 不在「準備/就緒」工作中送出正式單。
- Don't treat simulation balance / positions / P&L as real buying power. 不把模擬帳務當成真實資金。

### Step 1 — Open a SinoPac account 開立永豐證券帳戶

Tutorial 教學: <https://sinotrade.github.io/tutor/prepare/open_account/> · Open account 開戶: <https://www.sinotrade.com.tw/openact?strProd=0254&strWeb=0684&s=013211&utm_source=shioaji>

- You need a **Bank SinoPac account** as the delivery (交割) account. If you don't have one, choose **「我要開 DAWHO + 大戶投」** on the open-account page to open the bank and securities accounts together.
- 需要一個**永豐銀行帳戶**作為交割帳戶;若無,於開戶頁選「我要開 DAWHO + 大戶投」一次開立銀行 + 證券帳戶。

### Step 2 — Create API key & secret 申請 API 金鑰與密鑰

Tutorial 教學: <https://sinotrade.github.io/tutor/prepare/token/> · Portal 入口: <https://www.sinotrade.com.tw/newweb/PythonAPIKey/>

1. On the portal above (理財網 → 個人化服務 → API 管理頁面), click **新增 API KEY** ("Add API KEY"). 於 API 管理頁面點「新增 API KEY」。
2. Pass **two-factor authentication** (mobile or email) — the key is created only on success. 完成手機/Email 雙因子驗證,驗證成功才會建立金鑰。
3. On the key-settings screen, set the **到期時間 (expiration)**, the **applicable accounts**, an **IP 限制 (IP whitelist** — strongly recommended for security), and tick the **permission checkboxes** you need: 設定到期時間、適用帳戶、IP 限制(建議設定以提高安全性),並勾選所需權限:
   - ☐ **行情 / 資料 (Market / Data)** — market-data & reference APIs 行情/資料相關 API
   - ☐ **帳務 (Account)** — balance / margin / position APIs 帳務相關 API
   - ☐ **交易 (Trading)** — order placement APIs — **tick this to place orders** 交易相關 API(下單必勾)
   - ☐ **正式環境 (Production Environment)** — **tick this for live trading**; leave unticked for simulation-only keys 是否可用於正式環境(正式交易必勾;僅模擬可不勾)
4. On success you receive the **API Key** and **Secret Key**. **Save the Secret Key immediately — it is shown only once at creation and can never be retrieved again.** Store as `SJ_API_KEY` / `SJ_SEC_KEY` (see [Environment Variables](#environment-variables-環境變數)). 建立成功會取得 API Key 與 Secret Key;**Secret Key 僅在建立當下顯示一次,事後無法取得,務必立即保存。**

#### Permissions explained 權限說明

Tick only what the use case needs (least-privilege). When a user is unsure, explain each scope before they choose: 依用途勾選(最小權限);使用者不確定時,先解釋每項再讓他選:

| Permission 權限 | Covers 涵蓋範圍 | Tick when 何時勾選 |
|---|---|---|
| **行情 / 資料 (Market / Data)** | Real-time quotes (`subscribe` tick/bidask/quote), `snapshots`, `ticks`, `kbars`, `scanners`, `credit_enquires`, `short_stock_sources`, and contract data. 行情訂閱、快照、Tick、K 線、掃描排行、信用/借券查詢、合約資料。 | Any market-data work; also loads the contracts an order references. 任何行情需求;下單前載入合約也需要。 |
| **帳務 (Account)** | `account_balance`, `margin`, `list_positions`, `list_profit_loss`, `settlements`, `trading_limits`. 餘額、保證金、部位、損益、交割、額度。 | Reading balance / positions / P&L. 查詢帳務。 |
| **交易 (Trading)** | `place_order`, `cancel_order`, `update_order`, `update_status`, `list_trades`, combo orders. 下單、改單、刪單、委託/成交查詢、組合單。 | Placing or managing orders (incl. the simulation order test). 下單/管理委託(含模擬下單測試)。 |
| **正式環境 (Production Environment)** | Whether this key may run against the **production** endpoint (real orders/data). Unticked ⇒ simulation only. 此金鑰可否用於**正式環境**(實單/實資料);不勾僅限模擬。 | Live trading. 正式交易。 |

- **Least-privilege presets 最小權限組合:** read-only market data → `行情/資料`; portfolio dashboard → `行情/資料` + `帳務`; **order placing (incl. the test)** → `行情/資料` + `交易` (orders must load contracts first, so `行情/資料` is required alongside `交易`); **live trading** → the above **+ `正式環境`** (live needs both `交易` and `正式環境`). 唯讀行情只勾行情;看盤加帳務;**下單(含測試)需「行情/資料」+「交易」**(下單要先載合約);**正式交易再加「正式環境」**(正式需「交易」+「正式環境」併勾)。
- A **simulation-only key** can leave `正式環境` unticked and still complete the official sign-and-test flow. 純模擬金鑰可不勾正式環境,仍能完成官方簽署與測試。

#### IP allowlist IP 限制設定

Restricting the key to specific source IPs improves security — but **only set it if the IP is genuinely static**. 限制來源 IP 可提升安全性,但**僅在 IP 確實固定時**才設定:

- ✅ **Static / fixed IP 固定 IP** (enterprise leased line with a fixed IP, a fixed-IP cloud host, or an ISP fixed-IP plan): set the allowlist for security. 企業固定 IP 專線、固定 IP 雲主機、ISP 固定 IP 方案 → 可設白名單。
- 🚫 **Dynamic / uncertain IP 浮動或無法確定** (typical home broadband, mobile networks — the IP rotates on reconnect or DHCP-lease renewal): **leave it unset**, or a strict allowlist locks you out the moment the IP changes. 一般家用寬頻、行動網路(重連或租約到期就換)→ **只能不設定**,否則 IP 一變就把自己鎖在外面。
- ⚠️ **Confirm with the user 必須與使用者確認:** seeing the current public IP does **not** prove it is fixed. Most consumer/mobile connections are dynamic; only an ISP-confirmed static-IP plan (or a fixed-IP cloud host) counts. Ask the user — don't assume from a looked-up IP. 查得到目前公開 IP **不代表**它固定不變;多數家用/行動為浮動 IP,唯 ISP 明確的固定 IP 方案或固定 IP 雲主機才算。請與使用者確認,勿以查到的 IP 逕自判定。

### Step 3 — Sign API agreements & pass the test 簽署 API 約定書並通過測試

Tutorial 教學: <https://sinotrade.github.io/tutor/prepare/terms/>

This gate decides whether each account's `signed` field becomes `True`. Until it passes, production login succeeds but orders are rejected ("account not acceptable").
此關卡決定各帳戶的 `signed` 是否變為 `True`;未通過前,正式登入會成功但下單會被拒(account not acceptable)。

Signing does **not** create API Key / Secret Key. If credentials are not created yet, go back to [Step 2](#step-2--create-api-key--secret-申請-api-金鑰與密鑰). After signing is done, the next gate is the required simulation login/order test, not CA download.
簽署**不會**產生 API Key / Secret Key;若尚未建立憑證,回到 [Step 2](#step-2--create-api-key--secret-申請-api-金鑰與密鑰)。簽署完成後,下一關是必要的模擬登入/下單測試,不是下載 CA。

1. **Sign the API documents** on the direct page for the product you will trade — stock API signing: <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/>; futures/options API signing: <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/>. **Read the documents carefully first.** **Stock and futures are signed separately** — sign whichever products you will trade. 直接開對應商品的 API 簽署頁(證券 / 期貨選擇權),請先仔細閱讀文件;**證券與期貨需各別簽署**。
2. **Run the required simulation tests** (`simulation=True`): a **login test** plus a **`place_order` test** for each signed product (stock test uses 2890; futures uses a near-month TXF contract). The first test order also prints a one-time `Session up` message confirming the test server connection. 以模擬模式完成:登入測試 + 各已簽署商品的下單測試(證券測 2890,期貨測近月 TXF);首次下單會顯示一次性 `Session up` 訊息代表已連上測試伺服器。
3. **Wait for review — about 1 minute** after the tests complete (usually near-instant; allow a small buffer). 測試完成後等待審核**約 1 分鐘**(通常幾乎即時,保留一點時間差)。
4. **Verify** on the same direct signing page (stock <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/> · futures/options <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/>), or log in to production and read the `signed` field on each account (see [Account Setup](#account-setup-帳戶設定)). 於對應簽署頁或登入正式環境檢查各帳戶 `signed`。

Constraints 限制:
- **Test service window 可測試時間: Mon–Fri 08:00–20:00** (Taiwan time); **18:00–20:00 is restricted to Taiwan IPs**, 08:00–18:00 has no IP restriction. 週一至週五 08:00–20:00;18:00–20:00 僅限台灣 IP,08:00–18:00 無限制。
- shioaji **version must be ≥ 1.2**. 版本須 ≥ 1.2。
- The **signing timestamp must be earlier than the test timestamp**, or review will not pass. 簽署時間須早於測試時間,否則審核不通過。
- Stock and futures must be **tested separately**, and consecutive test orders need **≥ 1 second apart** so the system records them. 證券、期貨須各別測試,連續下單測試需間隔 ≥ 1 秒。
- For shioaji you only need **signing + the Python test** — the **`T4` test is NOT required**. 使用 shioaji 只需完成簽署與 Python 測試,**無需完成 `T4` 測試**。

Reference simulation test (run only the account types you signed) 參考測試腳本(只跑你已簽署的類型):

```python
import os, time
import shioaji as sj

api = sj.Shioaji(simulation=True)                       # paper mode 模擬模式
accounts = api.login(os.environ["SJ_API_KEY"], os.environ["SJ_SEC_KEY"])
print(accounts)                                         # login test 登入測試

# Stock order test 證券下單測試
sc = api.Contracts.Stocks["2890"]
st = api.place_order(sc, sj.StockOrder(
    price=sc.reference,                                 # reference = 平盤價
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_lot=sj.StockOrderLot.Common,
    account=api.stock_account,
))
print(st.status.status)                                 # PendingSubmit / Submitted = OK

time.sleep(1.1)                                         # ≥ 1s between stock & futures tests

# Futures order test 期貨下單測試
fc = api.Contracts.Futures["TXFR1"]
ft = api.place_order(fc, sj.FuturesOrder(
    price=fc.reference,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
))
print(ft.status.status)
```

> The first test order prints a one-time `Session up` message confirming the test-server connection. A status of `PendingSubmit` or `Submitted` means success; `Failed` means fix the order and retry. 首次下單會顯示一次性 `Session up`;狀態 `PendingSubmit`/`Submitted` 即成功,`Failed` 則修正後重試。
>
> CLI/HTTP users: start the server in simulation (`SJ_PRODUCTION=false`), confirm accounts with `shioaji auth accounts`, then place orders per the order reference. CLI/HTTP 使用者:以 `SJ_PRODUCTION=false` 啟動,`shioaji auth accounts` 確認帳戶後依訂單文件下單。

### Step 4 — Download & activate the CA certificate 下載並啟用 CA 憑證

Tutorial 教學: <https://sinotrade.github.io/tutor/prepare/token/>

CA is **required for production orders** and **not needed for simulation**. 正式下單需要 CA,模擬模式不需要。Download the **`Sinopac.pfx`** certificate by **either** method:

Do not send users to the signing pages for CA download. Use the API management page or eleader only.
不要把使用者導到簽署頁下載 CA;只能使用 API 管理頁或 eleader。

- **Method 1 — New SinoTrade web (recommended, cross-platform 跨平台,推薦):** on the **API 管理頁面** (<https://www.sinotrade.com.tw/newweb/PythonAPIKey/>), click **下載憑證 ("Download Certificate")**, then move the downloaded `Sinopac.pfx` to the path you will pass as `ca_path`. 於 API 管理頁面點「下載憑證」,將 `Sinopac.pfx` 移到 `ca_path` 指向的路徑。
- **Method 2 — eleader (Windows only 僅 Windows):** download **eleader** from <https://www.sinotrade.com.tw/CSCenter/CSCenter_13_3>, log in, go to **帳戶資料 → (3303) 帳號資料設定**, click **步驟說明**, and follow **CA 操作步驟說明**. 下載 eleader 登入後,帳戶資料 →（3303）帳號資料設定 → 步驟說明。

Then activate it in code with `activate_ca(...)` — see [CA Certificate Activation](#ca-certificate-activation-憑證啟用) below. The `ca_passwd` is the password you set when downloading; `person_id` is optional. On Windows, write the path with `/` or `\\`, not a single `\`. 以 `activate_ca(...)` 啟用(`ca_passwd` 為下載時設定的密碼,`person_id` 選填);Windows 路徑請用 `/` 或 `\\`。

### Step 5 — Production readiness 正式環境就緒

Once Steps 1–4 are done, switch to production, log in, activate CA, and confirm `signed`:
完成步驟 1–4 後,切到正式環境、登入、啟用 CA,並確認 `signed`:

```python
import shioaji as sj, os

api = sj.Shioaji(simulation=False)            # production 正式環境
api.login(os.environ["SJ_API_KEY"], os.environ["SJ_SEC_KEY"])
api.activate_ca(
    ca_path=os.environ["SJ_CA_PATH"],
    ca_passwd=os.environ["SJ_CA_PASSWD"],
)
assert api.stock_account.signed               # confirm onboarding passed 確認開通完成
# Production prerequisites are loaded. Do NOT place live orders unless the user
# explicitly requests and confirms a separate live-order task.
# 正式環境前置已就緒;除非使用者明確要求並確認獨立的下單任務,否則不要下正式單。
```

Check readiness at any time 隨時檢查就緒狀態:

```bash
shioaji utils api check --production          # verify key + production login 驗證金鑰與正式登入
```

### Browser-Assisted Onboarding 瀏覽器輔助開通

An agent can help with the web steps — open the official pages, read labels, locate controls, and (on your confirmation) click non-final navigation/selection controls. Just ask, e.g. *"open the API key page and show me which boxes to check."*
agent 可協助網頁步驟:開啟官方頁面、讀取畫面文字、定位控制項,並在你同意下點選非最終的導覽/選項。直接說:「幫我開 API key 頁面,告訴我要勾哪些。」

**Choose the existing browser capability first 先用既有的瀏覽器能力** — before installing anything: 在安裝任何工具前,依序:

1. The current agent's **built-in browser/plugin**, if it can open and interact with pages. 目前 agent 的內建 browser/plugin。
2. A **Chrome/profile-based tool** when the task needs your existing login session, cookies, or 2FA flow. 需要既有登入/cookies/2FA 時用 Chrome 工具。
3. **`agent-browser`** only when its tooling and CLI are both available, or the user agrees to install both. 兩者皆備或同意安裝時才用 `agent-browser`。
4. If no automation is available, give the **exact URLs + click-by-click guidance** for manual completion. 都沒有就給精確網址與逐步指引手動完成。

**Claude in Chrome (preferred for Claude Code) Claude Code 首選** — uses your visible, already-logged-in browser, so you supervise and handle every login/2FA yourself. 使用你可見且已登入的瀏覽器,你全程監督並親自處理登入/2FA。

- Prerequisites 前置: Chrome or Edge; the **Claude in Chrome** extension **≥ 1.0.36**; Claude Code **≥ 2.0.73**; a direct Anthropic plan (Pro/Max/Team/Enterprise). Not supported on Brave/Arc/WSL, nor via Bedrock/Vertex/Foundry. (Web Store: <https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn> · Docs: <https://code.claude.com/docs/en/chrome>)
- Enable 啟用: `claude --chrome`, or `/chrome` inside a session (also checks status / reconnects). When Claude hits a login page, CAPTCHA, or OTP it **pauses and asks you** to do it. 遇登入/CAPTCHA/OTP 會暫停請你處理。

**`agent-browser` (fallback) 後備方案** — only if the Chrome path is unavailable/unsuitable and you agree to set it up. Install the CLI with `npm i -g agent-browser` (the agent also needs the agent-browser skill/tooling enabled). 僅當 Chrome 路徑不可用且你同意時;以 `npm i -g agent-browser` 安裝 CLI(agent 還需啟用 agent-browser skill)。

```bash
agent-browser open "https://www.sinotrade.com.tw/newweb/PythonAPIKey/"
agent-browser screenshot ~/sinopac-key-page.png   # show you where you are
agent-browser snapshot -i                          # interactive elements with refs (@e1, @e2 …) → locate 行情·帳務·交易·正式環境
# after you confirm, check the boxes by their ref from the snapshot:
agent-browser check @e7                            # e.g. the 交易 (Trading) checkbox
agent-browser check @e8                            # e.g. the 正式環境 (Production Environment) checkbox
```

**Boundaries 界線:**

- ✅ **Allowed 可協助:** open the open-account / direct API signing / API-management URLs; snapshot and tell you which field you're on; recommend the API-Key permissions that match your goal; help set expiration / account / IP allowlist; download the CA cert **only after you confirm** the action and destination. 開官方頁、對應 API 簽署頁、定位、建議權限/到期/IP、經你確認後才下載憑證。
- 🙋 **Require user action 必須本人:** login passwords; SMS/email/OTP 2FA; reading and accepting legal terms; **the final submit/sign/confirm/建立 button** (unless you explicitly ask the agent to click after you've reviewed the page); copying/saving the one-time Secret Key. 密碼、2FA、閱讀同意條款、最終送出/簽署/建立、保存一次性 Secret Key。
- 🚫 **Do not 禁止:** store browser state / downloaded CA files / keys / passwords in git; keep a long-lived authenticated browser profile unless you ask for it; claim the account is approved before login/readiness checks confirm it; echo the Secret Key or CA password into chat. 不把瀏覽器狀態/憑證/金鑰存入 git、不宣稱已開通、不回顯密鑰。

**Suggested flow 建議流程** (when asked "open the pages / click through for me" 當你說「幫我開頁面/點流程」):

1. Open account page (if no SinoPac account). 無帳戶先開戶頁。
2. Open the direct API signing page for the needed product: stock <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/> or futures/options <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/>. 開對應商品的 API 簽署頁。
3. Open API management for key creation. 開 API 管理頁建立金鑰。
4. Recommend permissions by goal: market data → `行情/資料`; +account checks → `+帳務`; +simulation order test → `+交易`; production → add `正式環境` **only after you confirm production intent**. 依目標建議勾選。
5. Recommend an IP allowlist if your IP is stable; otherwise warn changing IPs will block usage. IP 穩定才建議白名單。
6. After key creation, **pause** and tell you to store the one-time Secret Key. 建立後暫停提醒保存 Secret Key。
7. Help download the `.pfx` and place it **outside the repo**. 協助下載憑證並放在 repo 外。
8. Return to the terminal and run the simulation login/order tests. 回到終端跑模擬測試。

### Readiness Checklist 準備完成檢查表

Use this when reporting the result of a prepare task. 回報準備任務時使用。

**Human web steps 人工網頁步驟:**

| Check 項目 | Done when 完成條件 | If not 未完成 |
|---|---|---|
| SinoPac account 帳戶 | Login works; account list is non-empty 登入成功且帳戶列表非空 | Open account page; guide opening 開戶頁引導 |
| API documents signed 已簽署 | Required accounts show `signed=True` after login 所需帳戶 `signed=True` | Open the direct product signing page: stock <https://www.sinotrade.com.tw/newweb/signCenter/S_openAPI/> or futures/options <https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/> 直接開對應商品簽署頁 |
| API Key created 已建立金鑰 | Key + one-time Secret stored **outside chat** 金鑰與密鑰已存於對話外 | Open API management; guide permissions/IP API 管理頁引導 |
| Production permission 正式權限 | Key has `正式環境` enabled when production is requested 已勾正式環境 | Revisit key settings or create a production key 重設或新建金鑰 |
| CA downloaded 已下載憑證 | `.pfx` exists **outside the repo**, path known `.pfx` 在 repo 外且路徑已知 | Download via API page or eleader 由 API 頁或 eleader 下載 |

**Local config & verification 本機設定與驗證:**

| Check 項目 | Run 執行 | Pass 通過條件 |
|---|---|---|
| Version 版本 | `print(sj.__version__)` / `shioaji server check` / `GET /api/v1/info` | `≥ 1.2` |
| Credentials 金鑰 | `.env` / secret store | `SJ_API_KEY` + `SJ_SEC_KEY` present, **not committed** |
| CA config 憑證 | `.env` / secret store | `SJ_CA_PATH` → `.pfx`; `SJ_CA_PASSWD` set for production |
| Login test 登入 | `login` / `shioaji auth accounts` / `GET /api/v1/auth/accounts` | Expected accounts returned 回傳預期帳戶 |
| Stock/futures sim test 模擬下單 | simulation `place_order` per account type | `Trade` status `PendingSubmit`/`Submitted`; ≥ 1s apart |
| CA expiry 憑證到期 | `get_ca_expiretime(...)` / `GET /api/v1/auth/ca_expiretime` | Present and not expired 存在且未過期 |
| Production readiness 正式就緒 | production login + accounts + CA expiry | All pass; **no production order sent** 全通過且未下正式單 |
| Quick check 快速檢查 | `shioaji utils api check --production` (shortcut for production login + account list; fall back to those if unavailable) | Key + production login OK 金鑰與正式登入成功 |

**Final report template 回報範本:**

```text
Shioaji prepare status:
- Done: installation, simulation login, stock simulation order test
- Needs user action: sign futures API document at https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/
- Blocked: production readiness — API Key lacks 正式環境 permission
- Not applicable: futures test (user requested stocks only)
- Live trading: not started; prepare tasks never place production orders
```

---

## Installation 安裝

Shioaji can be installed as a Python package or as a standalone CLI binary.
Shioaji 可作為 Python 套件或獨立 CLI 二進制檔安裝。

Choose the command by intent: new Python project -> `uv add shioaji`; one-off Python without a project -> `uv run --with shioaji python ...`; one-off CLI/server -> `uvx --from shioaji shioaji ...`; persistent CLI install -> `uv tool install shioaji`.
依目標選指令:新 Python 專案 -> `uv add shioaji`;不創專案的一次性 Python -> `uv run --with shioaji python ...`;一次性 CLI/server -> `uvx --from shioaji shioaji ...`;長期安裝 CLI -> `uv tool install shioaji`。

### Python Package 套件安裝

```bash
# uv (recommended 推薦)
uv add shioaji

# pip (alternative)
pip install shioaji
```

### CLI Tool Install CLI 工具安裝

```bash
# uv tool (recommended 推薦) — persistent install, puts `shioaji` on PATH
uv tool install shioaji
shioaji server start

# uvx — one-shot, no persistent install 一次性執行
uvx --from shioaji shioaji server start
```

### Standalone Binary 獨立二進制檔

**Linux / macOS:**

```bash
# Stable
curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | sh

# Pre-release
curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | CHANNEL=prerelease sh

# Specific version
curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | VERSION=v1.5.5 sh
```

**Windows (PowerShell):**

```powershell
# Stable
irm https://github.com/Sinotrade/Shioaji/releases/latest/download/install.ps1 | iex

# Pre-release
$env:CHANNEL="prerelease"; irm https://github.com/Sinotrade/Shioaji/releases/latest/download/install.ps1 | iex

# Specific version
$env:VERSION="v1.5.5"; irm https://github.com/Sinotrade/Shioaji/releases/latest/download/install.ps1 | iex
```

### Verify Installation 驗證安裝

```python
import shioaji as sj

api = sj.Shioaji()
print(f"Shioaji version: {sj.__version__}")
```

---

## Environment Variables 環境變數

All environment variables recognized by Shioaji. These can be set in a `.env` file (auto-loaded by CLI) or exported in the shell.
Shioaji 支援的所有環境變數。可以在 `.env` 檔案（CLI 自動載入）或 shell 中設定。

### Authentication 認證

| Variable 變數 | Required 必填 | Description 說明 |
|---|---|---|
| `SJ_API_KEY` | Yes (CLI/server) | API key for Shioaji authentication. Required for CLI and server mode. Python can pass directly to `login()`. |
| `SJ_SEC_KEY` | Yes (CLI/server) | Secret key for Shioaji authentication. Required for CLI and server mode. Python can pass directly to `login()`. |

### Client 客戶端

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `SJ_PROXY` | (none) | HTTP proxy URL for all API requests |
| `SJ_CA_PATH` | (none) | Path to CA certificate file (.pfx) for order signing |
| `SJ_CA_PASSWD` | (none) | CA certificate password |
| `SJ_HOME_PATH` | `~/.shioaji` | Custom home directory for token pool, contracts cache, and other state |
| `SJ_TIMEOUT` | `60000` | Solace request-reply timeout in milliseconds |
| `SJ_CONTRACTS_PATH` | (falls back to `SJ_HOME_PATH` > `~/.shioaji` > cwd) | Override contracts cache directory. Set to a writable path if the default is read-only. |

### Server 伺服器

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `SJ_PRODUCTION` | `false` | Enable production mode. Default is simulation. |
| `SJ_HTTP_ADDR` | `127.0.0.1:8080` | Server HTTP bind address. Priority: `SJ_HTTP_ADDR` > `SJ_BIND_ADDR` > `BIND_ADDR` > `127.0.0.1:8080` |
| `SJ_HTTP_CORS` | `true` | Enable CORS headers. Also reads `SJ_CORS` and `ENABLE_CORS` as fallbacks. |
| `SJ_HTTP_TIMEOUT` | `30` | HTTP request timeout in seconds. Also reads `TIMEOUT_SECONDS` as fallback. |
| `SJ_HTTP_LOG` | `true` | Enable HTTP request logging. Also reads `SJ_REQUEST_LOG` and `ENABLE_LOGGING` as fallbacks. |

### Unix Domain Socket (Unix only)

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `SJ_UDS_PATH` | `<session_dir>/server-<port>.sock` | Custom Unix domain socket path |
| `SJ_UDS_DISABLE` | `false` | Disable UDS listener entirely (HTTP only) |

### OpenAPI Documentation

| Variable 變數 | Default 預設 | Description 說明 |
|---|---|---|
| `ENABLE_OPENAPI` | `true` | Enable OpenAPI/Swagger docs endpoint |
| `OPENAPI_PATH` | `/docs` | URL path for the OpenAPI docs page |

### Legacy / Alias 舊版別名

| Variable 變數 | Alias for 等同於 |
|---|---|
| `SJ_BIND_ADDR` | `SJ_HTTP_ADDR` (lower priority fallback) |
| `BIND_ADDR` | `SJ_HTTP_ADDR` (lowest priority fallback) |
| `SJ_CORS` | `SJ_HTTP_CORS` (fallback) |
| `ENABLE_CORS` | `SJ_HTTP_CORS` (fallback) |
| `TIMEOUT_SECONDS` | `SJ_HTTP_TIMEOUT` (fallback) |
| `SJ_REQUEST_LOG` | `SJ_HTTP_LOG` (fallback) |
| `ENABLE_LOGGING` | `SJ_HTTP_LOG` (fallback) |

### Example .env File 範例 .env 檔案

Agents may create this Shioaji config file with placeholders, then stop and let the user replace the values locally. The initial `.env` should contain only these five parameters. Never fill real secrets for the user or ask them to paste secrets into chat.
Agent 可先建立此 Shioaji 設定檔並放 placeholder,再停下來讓使用者在本機替換內容。初始 `.env` 只應包含這五個參數。不要代填真實密鑰,也不要要求使用者把密鑰貼到對話。

```env
SJ_API_KEY=your_api_key
SJ_SEC_KEY=your_secret_key
SJ_CA_PATH=/path/to/Sinopac.pfx
SJ_CA_PASSWD=your_ca_password
SJ_PRODUCTION=false
```

---

## Login 登入

### Python: `api.login()` method

The Python binding authenticates via `api.login(api_key=..., secret_key=...)`. This uses token-based login.
Python 透過 `api.login(api_key=..., secret_key=...)` 進行認證，使用 token-based 登入。

```python
import shioaji as sj

api = sj.Shioaji()
accounts = api.login(
    api_key="your_api_key",
    secret_key="your_secret_key",
)
print(accounts)
```

**Sync login signature:**
```python
api.login(
    api_key: str,
    secret_key: str,
    fetch_contract: bool = True,       # Auto-fetch contracts after login
    contracts_timeout: int = 0,        # 0 = async (background), >0 = blocking (ms)
    contracts_cb: Callable = None,     # () once after all contracts, or (SecurityType) per type
    subscribe_trade: bool = True,      # Auto-subscribe to trade events
    receive_window: int = 30000,       # Token receive window (ms)
) -> List[Account]
```

**Async login signature:**
```python
await api.login(
    api_key: str,
    secret_key: str,
    fetch_contract: bool = True,
    subscribe_trade: bool = True,
    receive_window: int = 30000,
) -> List[Account]
```

Note: `contracts_timeout` and `contracts_cb` are only available in the sync client. The async client always loads contracts non-blocking.

`contracts_cb` accepts either:

- `callback()` -- called once after all contract types finish loading.
- `callback(security_type)` -- called after each contract type finishes loading. The argument is a `SecurityType` enum such as `SecurityType.Stock`, `SecurityType.Future`, `SecurityType.Option`, or `SecurityType.Index`.

Callbacks with more than one parameter raise `ShioajiTypeError`.

### CLI / Server: Environment Variables

The CLI and HTTP server read credentials from `SJ_API_KEY` and `SJ_SEC_KEY` environment variables. Authentication happens automatically on startup.
CLI 和 HTTP 伺服器從 `SJ_API_KEY` 和 `SJ_SEC_KEY` 環境變數讀取憑證，啟動時自動認證。

```bash
# Start server (reads SJ_API_KEY and SJ_SEC_KEY from env or .env)
# 啟動伺服器（從環境變數或 .env 讀取 SJ_API_KEY 和 SJ_SEC_KEY）
shioaji server start

# Or inline
SJ_API_KEY=xxx SJ_SEC_KEY=yyy shioaji server start
```

### Token Reuse 令牌重用

After login, the token is cached to `SJ_HOME_PATH` (default `~/.shioaji`). Subsequent logins with the same credentials reuse the cached token if it has not expired, avoiding unnecessary API calls.
登入後，令牌快取到 `SJ_HOME_PATH`（預設 `~/.shioaji`）。使用相同憑證的後續登入會重用未過期的快取令牌。

---

## Server Health and Auth Responses 伺服器狀態與認證回應

Use this section before deciding whether the server is ready, whether login/account setup succeeded, or whether production order prerequisites are satisfied. For exact installed-server HTTP fields, fetch `GET /openapi.json`; for CLI output parsing, use JSON output when available.

### Health / Info

| Check | Response shape | Agent decision |
|---|---|---|
| `GET /api/v1/health` / `shioaji server check` | `HealthResponse { status, version, timestamp, token_expires_in_seconds?, token_stale?, contract_count?, last_maintenance?, next_maintenance?, last_maintenance_error?, ca_expires_in_days?, ca_expired? }` | If unavailable, start the server or diagnose bind/daemon issues. If `token_stale=true`, re-login/restart before trading. If `contract_count` is low or zero, wait for contracts or check contract download. If `ca_expired=true`, renew/replace CA before production orders. |
| `GET /api/v1/info` | `ApiInfoResponse { name, version, description, protocols, simulation }` | Use `simulation` to decide whether to warn before real trading. Never assume production from server availability alone. |

### Accounts / Usage / CA

| Check | Response shape | Agent decision |
|---|---|---|
| Python `api.list_accounts()` / `GET /api/v1/auth/accounts` | Python `List[Account]` / HTTP `Vec<Account>` | Empty list means login/account setup failed or no usable account was returned. Choose stock/futures account by `account_type` (`S` for stock, `F` for futures/options). |
| `GET /api/v1/auth/usage` | `UsageOut` | Use this before changing market-data query parameters when historical data returns empty. If traffic quota is exhausted or near exhausted, treat empty `ticks`/`snapshots`/`kbars` as a quota issue first. |
| `GET /api/v1/auth/ca_expiretime?person_id=...` | `CaExpireResponse { person_id, expire_time }` | Missing or expired CA blocks production orders. Simulation does not require CA signing. |

### Trade Event Subscription

| Check | Response shape | Agent decision |
|---|---|---|
| Python `api.subscribe_trade(account)` / `POST /api/v1/auth/subscribe_trade` | `SubscribeTradeOut { account, subscribe_trade, ts }` | Required before consuming HTTP `/api/v1/stream/data/order_event` in production. If `subscribe_trade=false` or the call errors, do not assume order/deal events are active. In simulation, HTTP subscribe is a no-op success and is not required. |
| Python `api.unsubscribe_trade(account)` / `POST /api/v1/auth/unsubscribe_trade` | `SubscribeTradeOut { account, subscribe_trade, ts }` | Treat `subscribe_trade=false` as unsubscribed. In simulation, HTTP unsubscribe can return validation error because there is no production trade-event subscription to cancel. |

---

## Python Sync vs Async 同步與異步

Shioaji provides two Python client classes:
Shioaji 提供兩個 Python 客戶端類別：

### `Shioaji` (Sync 同步)

Standard synchronous client. Methods block until complete.
標準同步客戶端。方法會阻塞直到完成。

```python
import shioaji as sj

api = sj.Shioaji(simulation=True)
accounts = api.login(
    api_key="xxx",
    secret_key="yyy",
    contracts_timeout=10000,  # Wait before using api.Contracts immediately
)

# All methods are blocking 所有方法都是阻塞的
snapshots = api.snapshots([api.Contracts.Stocks["2330"]])
```

### `ShioajiAsync` (Async 異步)

True async/await client. All I/O methods return awaitables.
真正的 async/await 客戶端。所有 I/O 方法返回 awaitable。

```python
import shioaji as sj
import uvloop

async def main():
    api = sj.ShioajiAsync(simulation=True)
    accounts = await api.login(api_key="xxx", secret_key="yyy")
    await api.fetch_contracts(contract_download=True)

    # All I/O methods are async 所有 I/O 方法都是異步的
    snapshots = await api.snapshots([api.Contracts.Stocks["2330"]])

    # Async callbacks for streaming data 串流資料的異步回呼
    async def on_tick(tick):
        print(tick)
    api.set_on_tick_stk_v1_callback(on_tick)

uvloop.run(main())
```

This example uses [uvloop](https://pypi.org/project/uvloop/) (`pip install uvloop`), the recommended event loop for `ShioajiAsync` under high-throughput streaming. `uvloop.run(...)` is the preferred entry point since uvloop 0.18 (older versions: call `uvloop.install()` once before `asyncio.run(main())`). On Windows, uvloop is not supported (Linux/macOS only) — use the built-in asyncio loop instead with `import asyncio; asyncio.run(main())`. The code inside `main()` is identical either way.

本範例使用 [uvloop](https://pypi.org/project/uvloop/)（`pip install uvloop`），這是 `ShioajiAsync` 在高吞吐串流時建議的 event loop。自 uvloop 0.18 起建議使用 `uvloop.run(...)`（舊版則在 `asyncio.run(main())` 之前呼叫一次 `uvloop.install()`）。若是 Windows 使用者，uvloop 不支援（僅 Linux/macOS），請改用內建的 asyncio loop，以 `import asyncio; asyncio.run(main())` 執行 — 兩種方式下 `main()` 內的程式碼完全相同。

### Key Differences 主要差異

| Feature 功能 | `Shioaji` (Sync) | `ShioajiAsync` (Async) |
|---|---|---|
| Method calls 方法呼叫 | Blocking 阻塞 | `await` / `Awaitable` |
| Callbacks 回呼 | Regular functions 一般函式 | `async def` coroutines 協程 |
| Login extra params 登入額外參數 | `contracts_timeout`, `contracts_cb` | (none) |
| Data reception 資料接收 | Callback or Receiver | Callback or Receiver |
| Runtime model 執行模式 | Blocking wrapper | Awaitable wrapper |

---

## Account Setup 帳戶設定

After login, the API auto-selects default stock and futures accounts. You can query and override them.
登入後，API 自動選擇預設的股票和期貨帳戶。可以查詢和覆蓋。

### List Accounts 列出帳戶

```python
accounts = api.list_accounts()
for acc in accounts:
    print(f"{acc.account_type} {acc.broker_id}-{acc.account_id} ({acc.person_id})")
```

### Default Account Properties 預設帳戶屬性

```python
# Auto-selected after login 登入後自動選擇
stock_acc = api.stock_account      # First stock (S-type) account
futopt_acc = api.futopt_account    # First futures/options (F-type) account
```

### Override Default Account 覆蓋預設帳戶

```python
accounts = api.list_accounts()
# Set a specific account as default 設定特定帳戶為預設
api.set_default_account(accounts[1])
```

### API Usage 統計用量

Use `api.usage()` to inspect upstream API usage counters. The CLI equivalent is `shioaji auth usage`; HTTP uses `GET /api/v1/auth/usage`.
使用 `api.usage()` 查看上游 API 用量統計。CLI 對應 `shioaji auth usage`；HTTP 對應 `GET /api/v1/auth/usage`。

```python
usage = api.usage()
print(usage.connections)
print(usage.bytes)
print(usage.limit_bytes)
print(usage.remaining_bytes)

# Non-blocking sync style 非阻塞同步寫法
api.usage(timeout=0, cb=lambda usage: print(usage.remaining_bytes))

# Async client 非同步 client
usage = await async_api.usage()
```

### Account Fields 帳戶欄位

- `account_type` -- `"S"` (Stock) or `"F"` (Futures/Options)
- `person_id` -- ID number of the account holder
- `broker_id` -- Broker identifier
- `account_id` -- Account number
- `signed` -- Whether the account has signed the API agreement
- `username` -- Account holder name

---

## Common Constants 常用常數

Import enums from the `shioaji` module. These are used for orders, contracts, and subscriptions.
從 `shioaji` 模組匯入列舉。用於下單、合約和訂閱。

### SecurityType 證券類型

```python
from shioaji import SecurityType

SecurityType.Index   # Index 指數, HTTP value: "IND"
SecurityType.Stock   # Stock 股票, HTTP value: "STK"
SecurityType.Future  # Futures 期貨, HTTP value: "FUT"
SecurityType.Option  # Option 選擇權, HTTP value: "OPT"
```

### Exchange 交易所

```python
from shioaji import Exchange

Exchange.TSE       # Taiwan Stock Exchange 臺灣證券交易所
Exchange.OTC       # Over-the-Counter 櫃檯買賣中心
Exchange.OES       # Emerging Stock 興櫃
Exchange.TAIFEX    # Taiwan Futures Exchange 臺灣期貨交易所
Exchange.TIM       # TIM
```

### Action 買賣方向

```python
from shioaji import Action

Action.Buy         # Buy 買進
Action.Sell        # Sell 賣出
```

### OrderType 委託類型

```python
from shioaji import OrderType

OrderType.ROD      # Rest of Day 當日有效
OrderType.IOC      # Immediate or Cancel 立即成交否則取消
OrderType.FOK      # Fill or Kill 全部成交否則取消
```

### StockPriceType 股票價格類型

```python
from shioaji import StockPriceType

StockPriceType.LMT   # Limit order 限價
StockPriceType.MKT   # Market order 市價
```

### FuturesPriceType 期貨價格類型

```python
from shioaji import FuturesPriceType

FuturesPriceType.LMT   # Limit order 限價
FuturesPriceType.MKT   # Market order 市價
FuturesPriceType.MKP   # Market price (range market order) 範圍市價
```

### StockOrderLot 股票委託單位

```python
from shioaji import StockOrderLot

StockOrderLot.Common       # Regular lot 整股
StockOrderLot.BlockTrade   # Block trade 鉅額交易
StockOrderLot.Fixing       # Fixing session 定盤
StockOrderLot.Odd          # Odd lot (after-hours) 盤後零股
StockOrderLot.IntradayOdd  # Intraday odd lot 盤中零股
```

### StockOrderCond 股票委託條件

```python
from shioaji import StockOrderCond

StockOrderCond.Cash           # Cash 現股
StockOrderCond.Netting        # Netting 沖銷
StockOrderCond.MarginTrading  # Margin trading 融資
StockOrderCond.ShortSelling   # Short selling 融券
StockOrderCond.Emerging       # Emerging market 興櫃
```

### FuturesOCType 期貨開平倉類型

```python
from shioaji import FuturesOCType

FuturesOCType.Auto      # Auto 自動
FuturesOCType.New       # New position 新倉
FuturesOCType.Cover     # Cover/close position 平倉
FuturesOCType.DayTrade  # Day trade 當沖
```

### QuoteType 報價類型

```python
from shioaji import QuoteType

QuoteType.Tick     # Tick data 逐筆成交
QuoteType.BidAsk   # Bid/Ask data 五檔報價
QuoteType.Quote    # Quote data (legacy) 報價資料
```

---

## Simulation vs Production Mode 模擬與正式模式

By default, Shioaji runs in **simulation mode** (paper trading). This is safe for testing and development.
預設 Shioaji 使用**模擬模式**（模擬交易）。適合測試和開發。

### Setting the Mode 設定模式

**Python:**
```python
# Simulation (default) 模擬模式（預設）
api = sj.Shioaji(simulation=True)
api = sj.Shioaji()  # Also simulation 也是模擬

# Production 正式模式
api = sj.Shioaji(simulation=False)
```

**CLI / Server:**
```bash
# Simulation (default) 模擬模式（預設）
shioaji server start

# Production 正式模式
shioaji server start --production
shioaji server start --prod

# Or via env var 或透過環境變數
SJ_PRODUCTION=true shioaji server start
```

### Features with Simulation Guards 模擬模式限制

The following features behave differently or are unavailable in simulation mode:
以下功能在模擬模式下行為不同或不可用：

**Returns empty/default in simulation 模擬模式返回空值/預設值:**

- `account_balance` -- returns default AccountBalance
- `margin` -- returns default Margin
- `settlements` / `list_settlements` -- returns empty list / default
- `trading_limits` -- returns default TradingLimits
- `list_position_detail` -- returns empty list
- `list_profit_loss_detail` -- returns empty list
- `list_profit_loss_summary` -- returns empty summary
- `order_deal_records` -- returns empty list
- `reserve_stocks_summary` -- returns empty summary
- `reserve_stocks_detail` -- returns empty detail
- `earmark_stocks_detail` -- returns empty detail
- `reserve_stock` -- returns default response
- `earmark_stock` -- returns default response

**Errors in simulation 模擬模式回傳錯誤:**

- `place_comboorder` -- combo orders not available in paper/simulation mode
- `cancel_comboorder` -- combo orders not available in paper/simulation mode
- `update_combostatus` -- combo orders not available in paper/simulation mode

**Uses paper endpoints 使用模擬端點:**

- Order operations (`place_order`, `cancel_order`, `update_order`, `update_status`) -- routed to paper trading endpoints
- Portfolio operations (`list_positions`, `list_profit_loss`) -- routed to paper portfolio endpoints

**Skips CA signing 跳過 CA 簽章:**

- `sign_for_account` returns empty string in simulation (no CA certificate needed for paper orders)

**Fully available in simulation 模擬模式完全可用:**

- Market data: `subscribe`, `snapshots`, `ticks`, `kbars`, `credit_enquires`, `scanners`
- Contracts: `Contracts`, `load_contracts`
- Basic orders: `place_order`, `cancel_order`, `update_order`, `update_status`, `list_trades`

---

## CA Certificate Activation 憑證啟用

A CA certificate is required for placing orders in **production mode**. In simulation mode, CA signing is skipped automatically.
在**正式模式**下單需要 CA 憑證。模擬模式會自動跳過 CA 簽章。

### Activate CA 啟用憑證

**Python (sync):**
```python
result = api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="your_password",
    person_id=None,          # Optional: for multi-account (reserved)
)
# Returns True on success 成功返回 True
```

**Python (async):**
```python
result = await api.activate_ca(
    ca_path="/path/to/Sinopac.pfx",
    ca_passwd="your_password",
    person_id=None,
)
```

**CLI / Server:**
The server reads `SJ_CA_PATH` and `SJ_CA_PASSWD` environment variables for automatic CA activation.
伺服器從 `SJ_CA_PATH` 和 `SJ_CA_PASSWD` 環境變數自動啟用 CA。

### Check CA Expiry 查看憑證到期時間

```python
from datetime import datetime

expire_time: datetime = api.get_ca_expiretime(person_id="A123456789")
print(f"CA expires: {expire_time}")
```

**CLI:**
```bash
shioaji auth ca-expiretime --person-id A123456789
shioaji auth ca-expiretime --person-id A123456789 -f json
# → person_id + expire_time
```

### CA Workflow 憑證流程

1. **Download** the `Sinopac.pfx` certificate — either click **下載憑證** on the API 管理頁面 (cross-platform), or use the **eLeader** app (Windows only). See [Account Onboarding Step 4](#step-4--download--activate-the-ca-certificate-下載並啟用-ca-憑證) for both methods.
   下載 `Sinopac.pfx`:於 API 管理頁面點「下載憑證」(跨平台)或用 eleader(僅 Windows);兩種方法見上方開戶與開通步驟 4。
2. **Store** the file path and password securely (`.env` file or secret manager)
   安全存放檔案路徑和密碼（`.env` 檔案或密鑰管理器）
3. **Activate** after login and before placing production orders
   在登入後、正式下單前啟用
4. **Renew** before expiry using `get_ca_expiretime()` to check
   使用 `get_ca_expiretime()` 檢查，到期前更新

### Complete Production Setup 完整正式環境設定

```python
import shioaji as sj
import os

# Production mode 正式模式
api = sj.Shioaji(simulation=False)

# Login 登入
api.login(
    api_key=os.environ["SJ_API_KEY"],
    secret_key=os.environ["SJ_SEC_KEY"],
)

# Activate CA (required for production orders)
# 啟用 CA（正式下單必要）
api.activate_ca(
    ca_path=os.environ["SJ_CA_PATH"],
    ca_passwd=os.environ["SJ_CA_PASSWD"],
)

# Now ready for live trading
# 現在可以進行正式交易
print(f"Stock account: {api.stock_account}")
print(f"Futopt account: {api.futopt_account}")
```
