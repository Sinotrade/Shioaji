# Architecture Concepts 架構觀念

**Read this before reasoning about connections, timeouts, processes, or state.** It is the mental model the other references assume. Most task questions ("which timeout applies?", "do I need to start a server?", "why did I hit a connection limit?") are really architecture questions — answer them from here, don't guess.

**推理連線、逾時、行程或狀態之前,先讀這份。** 這是其他參考文件預設你已具備的心智模型。多數任務問題(「哪個 timeout 有效?」「要不要先開 server?」「為什麼撞到連線上限?」)其實是架構問題 — 從這裡找答案,不要猜。

## Table of Contents 目錄

1. [Three access layers, two process models 三個存取層、兩種行程模型](#1-three-access-layers-two-process-models-三個存取層兩種行程模型)
2. [One login = one connection 一個登入＝一條連線](#2-one-login--one-connection-一個登入一條連線)
3. [Two kinds of traffic: streaming vs request-reply 兩種流量：串流 vs 請求-回覆](#3-two-kinds-of-traffic-streaming-vs-request-reply-兩種流量串流-vs-請求-回覆)
4. [Timeouts: which one applies where 逾時：哪個在哪一段生效](#4-timeouts-which-one-applies-where-逾時哪個在哪一段生效)
5. [The process holds state 行程持有狀態](#5-the-process-holds-state-行程持有狀態)
6. [Two different authentications 兩種不同的認證](#6-two-different-authentications-兩種不同的認證)
7. [Simulation vs production lives in the process 模擬／正式環境綁在行程上](#7-simulation-vs-production-lives-in-the-process-模擬正式環境綁在行程上)

---

## 1. Three access layers, two process models 三個存取層、兩種行程模型

The three access layers (Python / CLI / HTTP API) are **not three separate systems** — they are three doors into the same trading core. But they run in **two different process shapes**, and this is the single most important thing to get right.

三個存取層(Python / CLI / HTTP API)**不是三套系統** — 它們是進入同一個交易核心的三道門。但它們以**兩種不同的行程型態**運行,這是最關鍵、必須先搞懂的一點。

**Model A — Python binding: in-process. Python 綁定：行程內**

```
Your Python process
┌───────────────────────────────┐
│  import shioaji → trading core │ ──→ SinoPac backend 永豐後端
└───────────────────────────────┘
```

`import shioaji` and `login()` run the trading core **inside your own Python process**. There is **no server to start** and no localhost HTTP hop. Calls go straight from your code to the core to the backend.

`import shioaji` 與 `login()` 讓交易核心**跑在你自己的 Python 行程裡**。**不需要開任何 server**,也沒有 localhost HTTP 中繼。呼叫直接從你的程式 → 核心 → 後端。

**Model B — CLI + HTTP API: client–daemon. CLI＋HTTP API:客戶端–常駐服務**

```
shioaji CLI ─┐
curl / SDK ──┤──HTTP/localhost──→  daemon (one trading core)  ──→ SinoPac backend
your app ────┘                     一個常駐服務、一個交易核心        永豐後端
```

`shioaji server start` (or the first data command, which auto-starts one) launches **one background daemon** that holds the trading core. The CLI, `curl`, and every language SDK are all just HTTP clients talking to that **single shared daemon**. Many clients, one core, one backend connection.

`shioaji server start`(或第一個資料指令會自動啟動一個)會啟動**一個背景常駐服務(daemon)**,核心就在裡面。CLI、`curl`、各語言 SDK 全都只是連到這**同一個共用 daemon** 的 HTTP 客戶端。多個客戶端、一個核心、一條後端連線。

**Practical implications 實務含意**

- "Do I need to start a server?" → **Python: no.** CLI/HTTP: yes (the CLI auto-starts the daemon for you).
- A per-call `timeout=` argument only exists on the **Python** layer (Model A). The HTTP path does not honor it — see §4.
- 「要不要先開 server?」→ **Python:不用。** CLI/HTTP:要(CLI 會自動幫你啟動 daemon)。
- 逐次呼叫的 `timeout=` 參數只存在於 **Python** 層(模型 A)。HTTP 路徑不吃它 — 見 §4。

---

## 2. One login = one connection 一個登入＝一條連線

Each process that calls `login()` opens **one live connection** to the SinoPac backend and consumes **one of the 5 connection slots allowed per person ID** (see the Rate Limits table in SKILL.md).

每個呼叫 `login()` 的行程都會對永豐後端開**一條即時連線**,並佔用**每個身分證字號允許的 5 條連線額度中的一格**(見 SKILL.md 的 Rate Limits 表)。

- **Python**: each Python process = its own login = its own connection = one slot. Ten Python processes each logging in = ten slots → you will hit the cap.
- **Daemon**: one connection backs **all** CLI/HTTP clients hitting it. A hundred HTTP clients through one daemon still cost **one** slot.

- **Python**:每個 Python 行程＝自己登入＝自己一條連線＝一格。十個各自登入的 Python 行程＝十格 → 會撞到上限。
- **Daemon**:一條連線支撐**所有**連到它的 CLI/HTTP 客戶端。一百個 HTTP 客戶端共用一個 daemon 仍只花**一**格。

**So**: a "connection limit" / too-many-connections error means **too many logged-in processes**, not too many requests. To serve many consumers cheaply, run **one daemon** and point every client at it instead of spawning many independent logins.

**所以**:「連線上限」/連線過多的錯誤代表**登入的行程太多**,不是請求太多。要便宜地服務多個消費端,就跑**一個 daemon** 讓所有客戶端連它,而不是開很多獨立登入。

---

## 3. Two kinds of traffic: streaming vs request-reply 兩種流量：串流 vs 請求-回覆

Over that one connection, two fundamentally different traffic patterns flow. Confusing them is the root of most timeout and "why did it hang / why did it stop" questions.

在那一條連線上,流動著兩種根本不同的流量模式。混淆它們是大多數逾時與「為什麼卡住／為什麼停了」問題的根源。

| | Streaming (push) 串流(推送) | Request-reply (wait) 請求-回覆(等待) |
|---|---|---|
| **What 哪些** | Real-time market data (tick / bidask / quote), order & deal events 即時行情、委託與成交事件 | Place/cancel order, query balance/positions, snapshots, kbars, contracts 下單／刪單、查餘額／部位、快照、K 棒、合約 |
| **Behavior 行為** | After you subscribe, data is **pushed continuously** until you unsubscribe or disconnect 訂閱後資料**持續被推送**,直到取消訂閱或斷線 | Send one request, **wait** for one reply 送出一個請求,**等待**一個回覆 |
| **How delivered 交付方式** | Python callbacks, or HTTP **SSE** streams 回呼函數,或 HTTP **SSE** 串流 | Return value / HTTP JSON response 回傳值／HTTP JSON 回應 |
| **Timeout 逾時** | **No per-message timeout** — the stream is long-lived **沒有逐筆逾時** — 串流是長壽命的 | The wait **is** what timeouts bound — see §4 等待**就是**逾時所限制的對象 — 見 §4 |

**Implications 含意**

- Streaming/SSE connections are **long-lived**. SDK clients must set their HTTP **read timeout to 0 / infinite** for SSE (this is why JAVA.md/Go/JS SSE examples disable read timeout). A normal request timeout on an SSE stream will kill it after a few idle seconds.
- Only **request-reply** operations "time out". A subscription does not time out; it ends when you unsubscribe or the connection drops.
- 串流／SSE 連線是**長壽命**的。SDK 客戶端對 SSE 必須把 HTTP **read timeout 設為 0／無限**(這就是 JAVA.md/Go/JS 的 SSE 範例關閉 read timeout 的原因)。對 SSE 串流套用一般請求逾時會在閒置幾秒後把它砍掉。
- 只有**請求-回覆**操作會「逾時」。訂閱不會逾時;它在你取消訂閱或連線中斷時才結束。

### Delivery is asynchronous — keep handlers light 交付是非同步的 — handler 要輕

Streamed data does not arrive as the return value of a call. After you subscribe (or set a callback / open an SSE stream), the data is **pushed to you asynchronously**, on a delivery path **separate from** your request-reply calls. In Python you receive it through the callback you registered; over HTTP you read it as SSE events. You do **not** poll, and you do **not** call a private start/handler helper — registering the callback (Python) or opening the SSE endpoint (HTTP) is the whole setup.

串流資料**不是**以呼叫的回傳值送達。訂閱(或設定 callback／開啟 SSE 串流)之後,資料會**非同步推送**給你,走的是與請求-回覆呼叫**分開**的交付路徑。在 Python 透過你註冊的 callback 收到;在 HTTP 以 SSE 事件讀取。你**不需要**輪詢,也**不需要**呼叫任何 private 的 start/handler helper — 註冊 callback(Python)或打開 SSE endpoint(HTTP)就是全部的設定。

Because delivery is asynchronous, the handler must stay **light and non-blocking**:

因為交付是非同步的,handler 必須保持**輕量、不阻塞**:

- A slow or blocking callback (heavy compute, a synchronous network/DB call, placing an order and waiting for its reply inside the handler) **stalls the delivery of subsequent messages** — quotes back up and you fall behind the market. Hand heavy work to a queue / another thread / async task and return quickly.
- Do not place a **request-reply** operation (place order, query balance) inside a streaming handler and block on its reply — you are mixing the two paths from §3 and will stall the stream. Trigger it asynchronously instead.
- 緩慢或阻塞的 callback(重運算、同步的網路／DB 呼叫、在 handler 裡下單並等回覆)會**卡住後續訊息的交付** — 報價會塞住,你就落後行情。把重活丟到 queue／另一條 thread／async task,然後快速返回。
- 不要在串流 handler 裡放**請求-回覆**操作(下單、查餘額)並阻塞等它回覆 — 那是把 §3 的兩條路徑混在一起,會卡住串流。改成非同步觸發。

---

## 4. Timeouts: which one applies where 逾時：哪個在哪一段生效

Timeouts live on **different legs of the path** and are **not interchangeable** — the most common mistake is assuming a knob works on a path where it has no effect. Only **request-reply** operations are bounded by these; subscriptions/SSE are not (§3).

逾時位於**路徑的不同段**且**不可互換** — 最常見的錯誤就是以為某個旋鈕在某條路徑上有效,但其實毫無作用。只有**請求-回覆**操作受這些限制;訂閱／SSE 不受限(§3)。

| Knob 旋鈕 | Leg it bounds 限制的路段 | Default 預設 | Set by 設定者 | Active on path 在哪條路徑生效 |
|---|---|---|---|---|
| Per-call `timeout=` (Python arg) | In-process call waiting for the backend reply 行程內呼叫等待後端回覆 | **30000ms** | Caller, per call 呼叫者,逐次 | **Python only** 僅 Python |
| `SJ_TIMEOUT` (env) | Server waiting for the backend reply 伺服器等待後端回覆 | **60000ms** | Server env, at daemon start daemon 啟動時的環境變數 | **HTTP/CLI path** (server-side; **not settable by HTTP clients**) HTTP/CLI 路徑(伺服器端;**HTTP 客戶端無法設定**) |
| HTTP client request/read timeout 客戶端請求／讀取逾時 | The HTTP request itself (client ↔ daemon) HTTP 請求本身(客戶端↔daemon) | Set by the client (SDK default varies) 由客戶端設定 | The HTTP client 你的 HTTP 客戶端 | **HTTP/CLI path** HTTP/CLI 路徑 |

**The rules that stop the guessing 終結亂猜的規則**

1. **Python path**: only the per-call `timeout=` matters. `SJ_TIMEOUT` is **not in play** (no HTTP hop; it is read only by the HTTP server module). Confirm a method's default by checking its functional reference rather than assuming.
2. **HTTP/CLI path, server side**: the per-call `timeout=` is **ignored** — the server uses `SJ_TIMEOUT` (60s) for how long it waits on the backend. An HTTP client **cannot** change `SJ_TIMEOUT`; it is fixed at the daemon by env var.
3. **HTTP/CLI path, client side**: the bound you actually control is **your HTTP client's own request/read timeout**. If it is shorter than the server's backend wait (`SJ_TIMEOUT`, 60s), your client **gives up first** and reports a timeout even though the server may still be completing the operation. For slow operations, set your client timeout generously (≥ the expected duration). (The server also exposes an HTTP request-timeout env var `SJ_HTTP_TIMEOUT`, default 30s.)
4. `timeout=0` (**sync** Python) = **non-blocking**: the call returns immediately with a placeholder and the real result arrives via callback. In **async** Python you `await` the call instead. See ADVANCED.md.

1. **Python 路徑**:只有逐次 `timeout=` 有效。`SJ_TIMEOUT` **不參與**(沒有 HTTP 中繼;它只被 HTTP 伺服器模組讀取)。某方法的預設值請查該功能參考確認,不要臆測。
2. **HTTP/CLI 路徑(伺服器端)**:逐次 `timeout=` 被**忽略** — 伺服器以 `SJ_TIMEOUT`(60s)作為等待後端的上限。HTTP 客戶端**無法**改 `SJ_TIMEOUT`;它在 daemon 端由環境變數固定。
3. **HTTP/CLI 路徑(客戶端)**:你真正能控制的上限是**自己 HTTP 客戶端的請求／讀取逾時**。若它比伺服器等待後端的時間(`SJ_TIMEOUT`,60s)短,你的客戶端會**先放棄**並回報逾時,即使伺服器其實還在完成操作。慢操作請把客戶端逾時設寬(≥ 預期耗時)。(伺服器另有 HTTP 請求逾時環境變數 `SJ_HTTP_TIMEOUT`,預設 30s。)
4. `timeout=0`(**sync** Python)＝**非阻塞**:呼叫立即回傳佔位結果,真正結果透過回呼送達。**async** Python 則用 `await` 等待。見 ADVANCED.md。

---

## 5. The process holds state 行程持有狀態

After login, the process (your Python process, or the daemon) holds **in-memory state**:

登入後,行程(你的 Python 行程,或 daemon)持有**記憶體內狀態**:

- **Contracts** — must be loaded before you can look one up. 合約 — 查詢前必須先載入。
- **Subscriptions** — your active market-data subscriptions live here. 訂閱 — 你的即時行情訂閱存在這裡。
- **Trades cache** — `list_trades` reads from this cache (fast, no round-trip); it is updated **automatically** on order/deal events. 委託快取 — `list_trades` 從這個快取讀取(快、不打後端);它在委託／成交事件時**自動**更新。

**Implications 含意**

- `list_trades` does **not** hit the backend every call — it returns the cached, auto-synced view. 不是每次都打後端,而是回傳自動同步的快取。
- Restarting the process / daemon **drops** subscriptions and in-memory state. Long-running trading needs a long-lived process. 重啟行程／daemon 會**清掉**訂閱與記憶體狀態。長時間交易需要長壽命行程。
- This is **why** the daemon model exists: keep one process alive holding state and the connection, serve many clients from it. 這就是 daemon 模型存在的**原因**:讓一個行程持續活著、持有狀態與連線,從它服務多個客戶端。

---

## 6. Two different authentications 兩種不同的認證

There are **two separate auth boundaries**. Conflating them turns a simple 401 into a wrong diagnosis.

有**兩道獨立的認證邊界**。把它們混為一談會讓一個單純的 401 被誤判。

| | Login (API key + secret) 登入 | HTTP client → daemon API-key auth HTTP 客戶端→daemon |
|---|---|---|
| **Who 對誰** | Authenticates **you to SinoPac** 對**永豐**認證你 | Authenticates an **HTTP client to the daemon** 對 **daemon** 認證 HTTP 客戶端 |
| **When 何時** | Once per process/daemon, at startup 每行程／daemon 一次,啟動時 | Per HTTP request 每個 HTTP 請求 |
| **How 方式** | `SJ_API_KEY` / `SJ_SEC_KEY` at `login()` | Bearer `SJ_API_KEY:SJ_SEC_KEY`, **only when the daemon binds to a non-localhost address**; on localhost there is no auth 僅當 daemon 綁到非 localhost 位址;localhost 不需認證 |

**So**: when you get a **401 from the HTTP API**, check the client↔daemon boundary **first** — a missing/invalid bearer on a non-localhost server is the usual cause, and it has nothing to do with your SinoPac login. A 401 can also be a backend auth error passed through from upstream, so it is not *exclusively* the daemon boundary; but a plain SinoPac login problem normally surfaces at `login()` / server start, not as a per-request 401. See HTTP_API.md and TROUBLESHOOTING.md.

**所以**:收到 **HTTP API 的 401** 時,**先**查客戶端↔daemon 這一道 — 非 localhost 伺服器缺少／無效的 bearer 是最常見原因,且與你的永豐登入無關。401 也可能是上游後端的認證錯誤被透傳回來,所以它**並非只**代表 daemon 那一道;但單純的永豐登入問題通常出現在 `login()`／server 啟動時,而非逐請求的 401。見 HTTP_API.md 與 TROUBLESHOOTING.md。

---

## 7. Simulation vs production lives in the process 模擬／正式環境綁在行程上

Simulation vs production is decided **when the process/daemon starts** (or at login), not per request. A running daemon is in **one** mode for its whole lifetime; to switch, stop and restart it (see SKILL.md "Simulation vs Production Safety"). An HTTP client cannot flip a request into production — the daemon's mode governs every order it places.

模擬 vs 正式是在**行程／daemon 啟動時**(或登入時)決定的,不是逐請求。運行中的 daemon 整個生命週期都在**單一**模式;要切換就停掉再重啟(見 SKILL.md「Simulation vs Production Safety」)。HTTP 客戶端無法把單一請求切到正式 — daemon 的模式管控它送出的每一筆委託。
