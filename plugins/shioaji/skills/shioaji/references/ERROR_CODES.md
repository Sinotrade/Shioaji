# Error Codes 錯誤判讀對照

判讀 Shioaji 使用者遇到的錯誤：從使用者貼的內容判斷錯誤形式，查出原因，給出處理方法。
使用時機：使用者貼出 exception traceback、HTTP error JSON、失敗的 `Trade`、或委託回報內容。

> 錯誤訊息文字可能隨伺服器版本微調，比對時抓關鍵字即可，不要求逐字相同。
> 處理方法分三類：**自行處理**（修正後即可重試）、**等待重試**（稍後再試，勿密集輪詢）、**聯絡永豐**（重試無效，請附完整錯誤訊息至客服群組詢問：[Telegram](https://t.me/joinchat/973EyAQlrfthZTk1) 或 [Discord](https://discord.gg/5nzmWCTnG7)）。

---

## 1. 判斷錯誤形式

Shioaji 的錯誤有四種形式，先從使用者貼的內容判斷是哪一種，再到對應章節查表：

| 使用者貼的內容 | 形式 | 查閱 |
|---|---|---|
| Python exception（如 `TokenError: StatusCode: 401, Detail: ...`）或 HTTP `{"code": 401, "message": ...}` | **形式一**：API 請求被拒（登入、查詢、刪改單、參數錯誤） | 第 2 節 |
| `Trade` 物件，`status.status = Failed` | **形式二**：下單被後台拒絕（**不會拋例外**） | 第 3 節 |
| 委託回報（callback 或 order-event SSE），`operation.op_code != "00"` | **形式三**：委託操作在交易所／後台失敗 | 第 4 節 |
| 沒有任何錯誤，但回空資料或回應帶 `status: false` | **形式四**：靜默失敗 | 本節末段 |

若使用者只給 status code（如「我遇到 401」）沒給訊息文字，**先請他貼完整錯誤訊息**（exception 的 Detail 或 HTTP 回應的 message），再比對第 2 節的表——同一個 code 對應多種原因，不要只憑 code 猜。可先告知該 code 的大類（如 401 = Token／金鑰／權限類）。

**關鍵：下單被拒不會拋例外。** `place_order` 會正常回傳，拒單資訊在回傳的 `Trade` 物件裡。
診斷時**不要重新下單**，檢查手上既有的 `Trade` 物件即可：

```python
# trade 是先前 place_order 的回傳值（或 api.list_trades() 裡的元素）
if trade.status.status == sj.constant.Status.Failed:
    print(trade.status.msg)  # 拒單原因，例如「非委託時間」
```

如果找不到當初的回傳值，用查詢的方式取回委託（不會產生新委託）：

```python
api.update_status()
for trade in api.list_trades():
    print(trade.status.status, trade.status.msg)
```

HTTP client 同理：檢查先前 `POST /api/v1/order/place` 回應 body 的 `status.status` 是否為 `"Failed"`（`200 OK` 不代表委託被接受）；事後查詢用 `POST /api/v1/order/trades`（會先更新狀態再列出委託，不會產生新委託），不要重打下單端點。

**形式四：HTTP 200 但靜默失敗。** 沒有 exception、沒有錯誤 code，要從回應內容判斷：

- 行情查詢（`ticks`／`kbars`／`snapshots`）回空資料：頭號原因是流量用量超額，先查 `api.usage()` 或 `GET /api/v1/auth/usage`，判讀流程見 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 歷史行情回空一節。
- 預收券款（reserve）操作：回應 `status` 為 `false` 時，失敗原因在 `info` 欄位，見 [RESERVE.md](RESERVE.md)。
- watchlist／`credit_enquire` 在後端異常時可能靜默回空結果：重試仍空、且查詢條件確認無誤時，至客服群組詢問。

---

## 2. 形式一：Exception／HTTP error（API 請求被拒）

### 2.1 Exception 與 HTTP status 對照

Python exception 皆繼承自 `sj.ShioajiError`，訊息格式為 `StatusCode: {code}, Detail: {訊息}`。HTTP API 客戶收到相同 code 的 `{"code": N, "message": ..., "details": ...}`。

| Status | Python exception | 意義 |
|---|---|---|
| 400 | `BadRequestError` | 參數錯誤或請求被拒（含登入失敗、刪改單被拒） |
| 401 | `TokenError` | 連線 Token 無效或過期 |
| 403 | `ShioajiPermissionError` | 權限不足 |
| 422 | `ValidationError` | 欄位驗證失敗 |
| 503 | `SystemMaintenance` | 系統維護、強制升版、服務暫停 |
| 其他 code | `ServerError`（訊息格式 `{呼叫}: request {topic} code: {N}, detail: {...}`） | 未分類的伺服器拒絕 |
| （逾時） | `ShioajiTimeoutError`（訊息格式 `Timeout Topic: {topic}, Corr: {id}, Timeout: {n}ms`） | 請求逾時 |
| （連線） | `ShioajiConnectionError` | 連線中斷 |

使用 `shioaji server`（本地 :8080）的客戶注意：**本地 server 的 401 與後端 Token 無關**，是 `Authorization` header 認證失敗，訊息為 `Missing Authorization header`、`Invalid Authorization format, expected: Bearer <api_key>:<secret_key>`、`Invalid token format, expected: <api_key>:<secret_key>` 或 `Invalid API credentials`——檢查啟動 server 用的金鑰與請求 header 即可，不用查下表。

注意：422 的 detail 不是字串，而是欄位錯誤**陣列**（`[{"loc": [...], "msg": "field required", "type": ...}]`）——看到這種格式，依 `loc` 指出的欄位修正請求參數即可。

CA 相關 exception 在本地拋出、不帶 status code：

| Exception | 訊息 | 處理方法 |
|---|---|---|
| `CaExpiredError` | `Ca has expired!` | 自行處理：至新理財網 API 管理頁（<https://www.sinotrade.com.tw/newweb/PythonAPIKey/>）重新申請並下載憑證，再重新啟用，見 [PREPARE.md](PREPARE.md) |
| `CaPasswordError` | `Ca Password Incorrect` | 自行處理：確認 CA 密碼（預設為身分證字號） |
| `CaError` | `CA not activated for: {id}` 等 | 自行處理：先執行 `api.activate_ca()`，見 [PREPARE.md](PREPARE.md) |
| `AccountNotSignError` | 帳戶未簽署 | 自行處理：完成 API 簽署，見 [PREPARE.md](PREPARE.md) |

以下依情境用使用者貼的 Detail／message 文字比對。

### 2.2 登入與 Token

| Status | 訊息 | 原因 | 處理方法 |
|---|---|---|---|
| 401 | `Not provided authenticated token` | 請求未帶 token（通常是未登入就呼叫需驗證的功能） | 自行處理：先 `login()` 再呼叫 |
| 400 | `Incorrect userid or password` | 模擬環境登入帳密錯誤 | 自行處理：核對 API Key／Secret Key |
| 401 | `Token is expired` | Token 已逾期（登入超過 24 小時），或觸發使用限制被踢退 | 自行處理：重新登入即可；若是超限被踢退，等 1 分鐘後再重登 |
| 401 | `Could not validate credentials` | Token 無效（格式錯誤或環境不符） | 自行處理：重新登入；確認模擬／正式環境一致 |
| 401 | `Token doesn't have permission` | API Key 權限未開放該功能 | 自行處理：至新理財網 API 管理頁（<https://www.sinotrade.com.tw/newweb/PythonAPIKey/>）確認並調整 API Key 的權限設定 |
| 400 | `key: {key_id} not exist.` | API Key 不存在（打錯或已刪除） | 自行處理：核對 API Key；必要時至 API 管理頁重新申請 |
| 401 | `key: {key_id} not match signature.` | Secret Key 錯誤（與 API Key 不成對） | 自行處理：核對金鑰；必要時至 API 管理頁重新產生 |
| 406 | `{key_id} is expired.` | API Key 已過期 | 自行處理：至新理財網 API 管理頁（<https://www.sinotrade.com.tw/newweb/PythonAPIKey/>）重新申請 API Key |
| 401 | `ip: {ip} not allow.` | 登入 IP 不在 API Key 的白名單內 | 自行處理：至 API 管理頁調整 IP 白名單，或改用允許的網路 |
| 401 | `Token doesn't have production permission.` | API Key 沒有正式環境權限 | 自行處理：至 API 管理頁確認權限；或先用模擬環境 |
| 451 | `Too Many Connections.` | 同一 person_id 最多 5 條連線，每次 `api.login()` 都算一條；常見原因是程式結束前沒 `logout()` 或程式沒真正關掉 | 自行處理：每次用完呼叫 `api.logout()`；若都有登出仍發生，關閉殘留程式或重開機後再登入；見 [CONCEPTS.md](CONCEPTS.md) |
| 406 | `Sign data is timeout.`（登入時出現） | 本機時間與伺服器相差超過 receive_window（預設 30 秒） | 自行處理：先校準系統時間，見 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 登入簽章逾時與 <https://sinotrade.github.io/zh/tutor/login/#_1> |
| 503 | `Please update the version of shioaji to at least {版本} ...` | 版本低於最低要求 | 自行處理：用 uv 升級至要求版本（`uv add "shioaji=={版本}"`；CLI 安裝用 `uv tool install --force "shioaji=={版本}"`）後重新登入，見 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| 400 | `密碼錯誤 {N} 次，請留意英文字母大小寫`（券商原文，錯滿 3 次的訊息附客服電話） | 登入密碼錯誤 | 自行處理：留意大小寫；錯 3 次會鎖定，鎖定後至新理財網重置密碼 |
| 503 | `登入密碼錯誤3次，請進行密碼重置` | 密碼錯誤三次鎖定 | 自行處理：至新理財網重置密碼後再重新登入 |
| 503 | `操作異常，請1分鐘後再重新登入` | 兩種可能：(1) 操作過於頻繁，Token 被移除；(2) 已被封鎖 | 等待重試：停止重試迴圈，等 1 分鐘後重新登入即可；若等待後仍持續出現，可能已被封鎖，請至客服群組找管理員處理 |
| 503 | 維護公告文字 | 系統維護時段 | 等待重試：維護結束後再試 |

### 2.3 下單、刪改單與帳戶

這些錯誤在送達交易後台前就被拒絕，會拋例外（與第 3 節的拒單不同）：

| Status | 訊息 | 原因 | 處理方法 |
|---|---|---|---|
| 406 | `Order price error.` | 價格不符檔位或漲跌幅限制 | 自行處理：修正價格；漲跌停價掛法見 [ORDERS.md](ORDERS.md) |
| 406 | `Account Not Acceptable.` | 帳號未完成開通（簽署＋模擬測試） | 自行處理：完成 API 簽署與模擬登入/下單測試，見 [PREPARE.md](PREPARE.md)；完成後仍出現才聯絡永豐 |
| 400 | `Ca is empty` | 正式環境下單未帶 CA 簽章 | 自行處理：先啟用 CA，見 [PREPARE.md](PREPARE.md) |
| 400 | `Please run update_status first to get trade details.` | 刪改單前未先更新委託狀態 | 自行處理：先呼叫 `api.update_status()` 再操作 |
| 400 | `無原委託內容` / `對應不到原序號` | 原委託已不存在或序號對不上 | 自行處理：`update_status()` 重新取得委託清單 |
| 400 | `無法刪單/改量` | 委託可能已成交或已刪除 | 自行處理：`update_status()` 確認最新狀態 |
| 400 | `不允許刪當日未成交委託` | 該單型不允許刪單 | 確認單型規則；有疑問聯絡永豐 |
| 406 | `seqno: {n} not allow.` | 序號不屬於此帳戶 | 自行處理：使用 `list_trades()`／`update_status()` 回傳的委託物件操作 |
| 422 | `Account Type: {t} not supported.` | 端點不支援此帳戶類型 | 自行處理：改用對應帳戶（證券／期貨） |
| 400 | `Just allow order with two contracts.` | 組合單必須恰為兩腳 | 自行處理：見 [COMBO_ORDERS.md](COMBO_ORDERS.md) |
| 406 | `Please sign {broker_id}{account_id} first.` | 帳戶未完成簽署 | 自行處理：完成 API 簽署，見 [PREPARE.md](PREPARE.md) |
| 400 | 前置檢核訊息（如 `Please provide {欄位} option.`、價格／數量上限檢核） | 下單參數未通過前置檢核 | 自行處理：依訊息修正參數，見 [ORDERS.md](ORDERS.md) |
| 501 | `The Api Topic not Implemented.` | 呼叫到伺服器不存在的端點（通常是版本不符） | 自行處理：升級 shioaji 後重試 |
| 417 | 預收券款相關原始訊息 | 預收券款（reserve）後端服務回錯 | 依訊息內容處理，見 [RESERVE.md](RESERVE.md)；無法判斷時至客服群組詢問 |

刪改單的 400 detail 若是上表以外的**中文訊息**（回應可能附帶 `sts_code` 欄位），代表操作被交易後台拒絕——直接用第 3 節的表比對該中文訊息判讀即可。

### 2.4 查詢

| Status | 訊息 | 處理方法 |
|---|---|---|
| 400 | `The query date range must be less than {n} days.` | 自行處理：縮小查詢區間 |
| 400 | `The list_margin just supports futures account.` | 自行處理：改帶期貨帳戶 |
| 400 | `Only stock accounts are supported for balance check.` | 自行處理：改帶證券帳戶 |
| 400 | `Please take start time and end time parameter.` / `Please take last_cnt parameter.` | 自行處理：補齊查詢參數 |
| 404 | `Data not found.` | 常為合法查無資料；先確認查詢條件（日期、帳戶、代碼） |
| 503 | `Service is unavailable, Please try again later.` | 等待重試 |
| 200 | `account_balance` 的 `errmsg` = `查無銀行交割帳號` / `非永豐銀行交割帳號` | 帳號未綁永豐銀行交割帳戶；自行確認交割戶設定，開戶或變更請洽營業員 |
| 200 | `account_balance` 的 `errmsg` 為其他銀行端錯誤（如 `SP Bank Error (Code: {n})`） | 銀行端餘額查詢失敗，聯絡永豐：至客服群組反應 |
| 4xx | `trading_limits` 於非開放時段查詢的錯誤（訊息由後端回傳） | 僅交易日 08:30–15:00 開放查詢，時段外出現錯誤屬預期行為，等開放時段再查 |
| 500 | `Internal Server Error` / `Please check param.` | 聯絡永豐：至客服群組反應 |
| 504 | `... API call timed out`（如 `SOR Gateway API call timed out`） | 聯絡永豐：後端服務逾時，至客服群組反應 |

### 2.5 下單中台連線（STS）

STS 是下單中台，需要經過下單中台的操作（下單、刪改單、帳務查詢等）都可能在其連線異常時遇到。**遇到這類錯誤一律聯繫客服群組**：

| Status | 訊息 | 原因 | 處理方法 |
|---|---|---|---|
| 408 | `STS Request Timeout` | 下單中台回應逾時 | 聯絡永豐：至客服群組回報；**下單類操作在重送前必先 `update_status()` 確認委託是否已成立**，避免重複下單 |
| 503 | `STS Service Unavailable` | 下單中台連線中斷、重連中 | 聯絡永豐：至客服群組回報 |
| 500 | `STS Sending Error` / `STS Data Receive Error` | 下單中台傳送／接收資料異常 | 聯絡永豐：至客服群組回報 |

### 2.6 客戶端本地錯誤

這些錯誤由 shioaji 在本機檢查後拋出，不經過伺服器，訊息不帶 `StatusCode`：

| 訊息 | 原因 | 處理方法 |
|---|---|---|
| `Not authenticated` / `not authenticated` | 尚未登入就呼叫需登入的功能 | 自行處理：先 `api.login()` |
| `Invalid {Enum}: {值}`（如 `Invalid Action: buy`） | enum 字串大小寫或拼字錯 | 自行處理：改用正確值（如 `Buy`）或 `sj.constant` 常數 |
| `{Type} must be {Type} enum or string` / `order must be StockOrder, FuturesOrder, or Order` | 參數型別錯誤 | 自行處理：依訊息修正參數型別 |
| `Trade {id} not found in cache` | 刪改單的委託不在本地快取 | 自行處理：先 `update_status()` 取回委託再操作 |
| `api_key must be at least 10 characters` / `invalid secret_key (base58 decode failed)` | 金鑰貼錯（貼到片段、多了空白或換行） | 自行處理：重新完整複製 API Key／Secret Key |
| 錯誤訊息帶 `(cached from a previous failure; will retry server in {n}s)` 後綴 | 登入失敗後短時間內重試，回的是本地快取的舊錯誤，**不代表新設定無效** | 自行處理：等提示秒數過後再重試 |
| `Path: {path} without write permission. Please set SJ_CONTRACTS_PATH to a writable path.` | 商品檔快取目錄不可寫（常見於 Docker／唯讀環境） | 自行處理：把 `SJ_CONTRACTS_PATH` 指到可寫路徑 |
| `Login To Activate Ca` | 未登入就呼叫 `activate_ca()` | 自行處理：先 `login()` 再啟用 CA |
| `contracts: wire version mismatch (server {X}, client supports {Y})` | Contract V2 版本不符 | 自行處理：升級 shioaji |
| `contracts: not populated for {region}/{type}` / `contracts: transient transport failure: ...` | 當日商品檔尚未產製／暫時性傳輸失敗 | 等待重試 |
| `No stock account found` / `No futures account found` / `{api}: no ... account found` | 未帶帳戶且登入帳號無對應類型帳戶 | 自行處理：確認帳戶類型；無該類帳戶需先開戶 |
| `combo order requires exactly 2 legs, got {n}` / `Combo orders are not available in paper/simulation mode` | 組合單本地檢核 | 自行處理：組合單須恰為兩腳、僅正式環境支援，見 [COMBO_ORDERS.md](COMBO_ORDERS.md) |
| `Must specify either price or qty to update` | 改單未帶 price 或 qty | 自行處理：帶上要修改的欄位 |

---

## 3. 形式二：下單被拒（讀 `trade.status.msg`）

下單被後台拒絕時不拋例外，原因是 `trade.status.msg` 裡的中文訊息（`status_code` 是後台內部代碼，直接以 `msg` 文字判斷即可）。

### 3.1 正式環境常見訊息

| `msg` 訊息 | 原因 | 處理方法 |
|---|---|---|
| `非委託時間` | 不在委託時段 | 自行處理：等委託時段；盤前可用預約單，見 [RESERVE.md](RESERVE.md) |
| `非預約下單時間` / `委託預約單時間` | 預約單時段規則 | 自行處理：確認預約時段，見 [RESERVE.md](RESERVE.md) |
| `處理中, 請再確認委託狀態` | 委託處理中，結果未定 | 等待重試：`update_status()` 確認，**不要直接重送** |
| `連線逾時,請再確認委託狀態` | 委託送出但結果未知 | **重送前必先 `update_status()` 確認**，避免重複下單 |
| `忙線中, 請稍後再查` | 後台忙碌 | 等待重試 |
| `買賣值有錯` / `交易條件值有錯` | 參數組合不合法 | 自行處理：檢查 `action`、`price_type`、`order_type`、`order_cond` 組合，見 [ORDERS.md](ORDERS.md) |
| `無此商品代碼` | 合約代碼錯誤 | 自行處理：確認合約，見 [CONTRACTS.md](CONTRACTS.md) |
| `憑證驗章失敗...` | CA 簽章問題 | 自行處理：重新啟用 CA；仍失敗至客服群組詢問 |
| `由於風險條件,無法下單` | 風控限制 | 聯絡永豐：所屬營業員 |
| `超過當日委託金額上限`（含買進/賣出/現股賣出）/ `超過當日委託口數上限` | 已達當日額度上限 | 聯絡永豐：調整額度請洽營業員 |
| `圈存失敗`（含餘額不足等） | 交割戶資金不足或戶別限制 | 自行處理：確認交割戶資金；戶別問題洽營業員 |
| `暫停接受委託` | 後台暫停收單 | 等待重試 |
| `非交易時間, 暫不開放, 請稍候再作業` | 非交易時段 | 自行處理：等交易時段 |
| `已達到最多連線` / `登入人數滿載...` | 連線滿載 | 自行處理：關閉多餘連線後重試 |
| `您的帳號目前無法使用API，請洽營業同仁提出申請` | API 使用權限未開通 | 聯絡永豐：洽營業員申請 API 權限，開通流程見 [PREPARE.md](PREPARE.md) |
| `系統有誤,請洽客服人員` | 後台異常 | 聯絡永豐：至客服群組反應 |

### 3.2 模擬環境訊息

模擬環境有自己的檢核，這些訊息只在模擬出現：

| `msg` 訊息 | 原因 | 處理方法 |
|---|---|---|
| `帳號不存在` | 模擬帳號未建立 | 自行處理：重新以模擬模式登入一次（登入時會建立模擬帳號） |
| `價格超過漲跌幅範圍` | 價格超出漲跌停 | 自行處理：修正價格 |
| `價格檔數錯誤` / `價格錯誤` | 價格不符檔位 | 自行處理：依商品檔位修正價格 |
| `集合競價時段不可輸入市價／ IOC ／ FOK 委託` | 開收盤集合競價時段限制 | 自行處理：改用限價 ROD，或等連續交易時段 |
| `集保賣出餘股數不足，餘股數 {n} 股` | 模擬庫存不足 | 自行處理：確認模擬持倉數量 |
| `該商品非當沖` | 商品不可當沖 | 自行處理：取消當沖條件或換商品 |
| `委託數量已完全刪除` / `該委託書已完全成交，不可刪單/改單或改價` | 對已刪除／已成交的委託操作 | 自行處理：`update_status()` 確認委託狀態 |
| `該筆委託無法處理，原委託有異常狀況！` | 原委託異常 | 自行處理：`update_status()` 後重新操作；持續發生至客服群組詢問 |
| `無原委託內容` | 找不到原委託 | 自行處理：`update_status()` 重新取得委託清單 |

---

## 4. 形式三：委託回報 `op_code`

委託／成交回報（`order_deal_event` callback、order-event SSE）帶 `operation` 區塊：

```python
{"op_type": "New", "op_code": "00", "op_msg": ""}
```

- `op_code == "00"`：該操作（`New`／`Cancel`／`UpdatePrice`／`UpdateQty`）成功。
- `op_code != "00"`：操作失敗，原因在 `op_msg`（中文，來自交易所／後台）。先原文轉述 `op_msg`，再依第 3 節同樣邏輯判斷情境。
- `op_code` 與其他章節**不是**同一套代碼，不要交叉查表，以 `op_msg` 文字為準。

回報處理與事件格式見 [ORDERS.md](ORDERS.md)。

---

## 5. 重試決策摘要

1. **逾時或「處理中」後絕不直接重送委託**（`STS Request Timeout`、`連線逾時`、`處理中`）：先 `update_status()` 確認委託狀態。重複下單比漏單更糟。
2. **自行處理類**（參數錯、Token 過期、未帶 CA、未更新狀態、金鑰／權限設定）：修正後即可重試；金鑰與權限問題到新理財網 API 管理頁自行調整。
3. **等待重試類**（維護、忙線、`操作異常`）：等待後再試，不要密集輪詢——可能觸發封鎖。
4. **聯絡永豐類**（下單中台異常、風控、額度、簽署、被封鎖）：重試無效，請使用者附上完整錯誤訊息至客服群組（[Telegram](https://t.me/joinchat/973EyAQlrfthZTk1) 或 [Discord](https://discord.gg/5nzmWCTnG7)）詢問；額度與風控類也可洽所屬營業員。
