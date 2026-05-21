# Troubleshooting 常見問題

Common issues and solutions for rshioaji (package: `rshioaji`, import: `import shioaji as sj`).
rshioaji 常見問題與解決方案（套件名稱：`rshioaji`，引入方式：`import shioaji as sj`）。

---

## Orders 下單相關

### How to place MKT/MKP orders 如何下市價單

The MKT + ROD restriction is **TAIFEX-only** — it does not apply to TWSE stocks.
MKT + ROD 限制**僅期交所 (TAIFEX)** 適用，證交所股票不受此限。

- **Futures / options (TAIFEX)**: only `MKT` is restricted — it must pair with IOC or FOK; `MKT + ROD` is rejected with `op_code` 9938. `LMT` and `MKP` both accept ROD/IOC/FOK.
  **期貨／選擇權**：僅 `MKT` 受限——必須搭配 IOC 或 FOK，`MKT + ROD` 會被退單（`op_code` 9938）；`LMT` 與 `MKP` 三種委託條件皆可。
- **Stocks (TWSE)**: every `price_type` × `order_type` combination is valid — MKT/LMT/MKP each accept ROD/IOC/FOK. Symptom worth knowing: a stock MKT + IOC with no immediate counterparty returns `op_code` 48, which is normal liquidity behaviour, not an SDK issue.
  **股票**：所有 `price_type` × `order_type` 組合皆有效；MKT/LMT/MKP 都可搭配 ROD/IOC/FOK。若股票下 MKT + IOC 沒立即成交，會回 `op_code` 48，這是市場流動性問題，並非 SDK 錯誤。

```python
import shioaji as sj

# Futures / options — MKT must use IOC or FOK
# 期貨／選擇權 — MKT 必須使用 IOC 或 FOK
order = api.Order(
    action=sj.constant.Action.Buy,
    price=0,  # MKT ignores price 市價單忽略價格
    quantity=1,
    price_type=sj.constant.FuturesPriceType.MKT,
    order_type=sj.constant.OrderType.IOC,  # MKT must use IOC / FOK; MKP / LMT accept ROD too 僅 MKT 須 IOC/FOK
    octype=sj.constant.FuturesOCType.Auto,
    account=api.futopt_account,
)

# Stocks — MKT accepts ROD too
# 股票 — MKT 可搭配 ROD
order = api.Order(
    action=sj.constant.Action.Buy,
    price=0,
    quantity=1,
    price_type=sj.constant.StockPriceType.MKT,
    order_type=sj.constant.OrderType.ROD,  # Or IOC / FOK 也可用 IOC / FOK
    account=api.stock_account,
)
```

### How to place limit up/down orders 如何掛漲跌停價

Get limit prices from contract:
從合約取得漲跌停價：

```python
contract = api.Contracts.Stocks["2330"]

# Limit up 漲停價
price = contract.limit_up

# Limit down 跌停價
price = contract.limit_down

order = api.Order(
    action=sj.constant.Action.Buy,
    price=price,
    quantity=1,
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    account=api.stock_account
)
```

---

## Streaming 行情相關

### Quote stream stops after few ticks 行情只收到幾筆就斷了

**Problem 問題:** Script exits immediately after subscribing.
訂閱後程式立即結束。

**Solution 解決方案:** Keep the program running with `Event().wait()`:
使用 `Event().wait()` 讓程式保持運行：

```python
import shioaji as sj
from threading import Event

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

@api.on_tick_stk_v1()
def on_tick(exchange, tick):
    print(tick)

api.quote.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.constant.QuoteType.Tick
)

# Keep program alive 保持程式運行
Event().wait()
```

---

## Account 帳戶相關

### Account not acceptable 帳戶無法使用

**Possible causes 可能原因:**

1. **Terms not signed 未簽署條款**
   - Complete terms signing at Sinopac website
   - 在永豐金網站完成條款簽署

2. **API test not completed API測試未完成**
   - Complete API testing flow
   - 完成 API 測試流程

3. **Using update_status without all accounts signed 使用 update_status 但並非所有帳戶都已簽署**
   - `update_status()` queries all accounts by default
   - Specify account: `api.update_status(api.stock_account)`
   - `update_status()` 預設查詢所有帳號，請指定帳號

---

## Environment 環境設定

### Installation 安裝

rshioaji is installed via `rshioaji` but imported as `shioaji`:
rshioaji 透過 `rshioaji` 安裝，但以 `shioaji` 引入：

```bash
# Install with uv 使用 uv 安裝
uv tool install rshioaji

# Import (same as original shioaji) 引入方式不變
import shioaji as sj
```

### Change log file path 更改 log 檔案路徑

Set environment variable before importing shioaji:
在 import shioaji 之前設定環境變數：

```python
import os
os.environ["SJ_LOG_PATH"] = "/path/to/shioaji.log"

import shioaji as sj  # Import after setting env
```

Or in shell:
或在 shell 中：

```bash
# Linux/macOS
export SJ_LOG_PATH=/path/to/shioaji.log

# Windows
set SJ_LOG_PATH=C:\path\to\shioaji.log
```

### Change contracts download path 更改合約下載路徑

```python
import os
os.environ["SJ_CONTRACTS_PATH"] = "/path/to/contracts"

import shioaji as sj
```

---

## Connection 連線相關

### Rate limit exceeded 超過流量限制

**Limits 限制:**

| Category 類別 | Limit 限制 |
|---------------|------------|
| Quote query 行情查詢 | 50 / 5 sec |
| Accounting 帳務 | 25 / 5 sec |
| Orders 委託 | 250 / 10 sec |
| Connections 連線 | 5 per person |
| Daily logins 每日登入 | 1000 times |

**Solution 解決方案:**
- Use callbacks instead of polling 使用回調代替輪詢
- Add delays between requests 請求間加入延遲
- Cache results when possible 盡可能快取結果

### Connection lost 連線中斷

Use event callback to monitor connection:
使用事件回調監控連線：

```python
@api.on_event
def event_callback(resp_code: int, event_code: int, info: str, event: str):
    print(f"Event: {event_code} - {event}")

    # Reconnecting
    if event_code == 12:
        print("Reconnecting...")
    # Reconnected
    elif event_code == 13:
        print("Reconnected!")
```

---

## HTTP API Troubleshooting HTTP API 疑難排解

The rshioaji HTTP server (`shioaji server start`) provides REST and SSE endpoints. Below are common issues.
rshioaji HTTP 伺服器（`shioaji server start`）提供 REST 和 SSE 端點。以下是常見問題。

### Common HTTP Error Responses 常見 HTTP 錯誤回應

All HTTP errors return JSON format:
所有 HTTP 錯誤皆以 JSON 格式回傳：

```json
{"code": 400, "message": "human-readable message", "details": {...}}
```

| Status Code 狀態碼 | Meaning 意義 | Common Cause 常見原因 |
|---------------------|--------------|------------------------|
| 400 | Bad Request 請求錯誤 | Invalid parameters, account not signed, CA issues 參數錯誤、帳戶未簽署、CA 問題 |
| 401 | Unauthorized 未授權 | Missing or invalid `Authorization` header (non-localhost) 缺少或無效 `Authorization` 標頭（非 localhost） |
| 422 | Validation Error 驗證錯誤 | Backend validation failure (e.g., invalid date, count < 1) 後端驗證失敗（如日期無效、count < 1） |
| 500 | Internal Error 內部錯誤 | Connection lost, timeout, decode failure 連線中斷、逾時、解碼失敗 |

### Authentication on Non-localhost 非 localhost 的認證

When the HTTP server binds to a non-loopback address (e.g., `0.0.0.0:8080`), API key authentication is **automatically enabled**. Requests without valid credentials will receive 401.
當 HTTP 伺服器繫結至非迴圈位址（例如 `0.0.0.0:8080`）時，API 金鑰認證**自動啟用**。缺少有效憑證的請求將收到 401。

**Required header format 必要的標頭格式:**
```
Authorization: Bearer <SJ_API_KEY>:<SJ_SEC_KEY>
```

**Example 範例:**
```bash
# Non-localhost bind requires auth 非 localhost 繫結需要認證
curl -H "Authorization: Bearer YOUR_API_KEY:YOUR_SECRET_KEY" \
  http://your-server:8080/api/v1/auth/accounts
```

**Troubleshooting checklist 疑難排解檢查清單:**

1. **Confirm bind address 確認繫結位址** — localhost (`127.0.0.1`) requires no auth; any other address requires auth
   localhost（`127.0.0.1`）不需認證；其他位址需要認證
2. **Check header format 檢查標頭格式** — Must be `Bearer <key>:<secret>`, not `Basic` or bare token
   必須是 `Bearer <key>:<secret>`，不是 `Basic` 或裸令牌
3. **Verify env vars 確認環境變數** — `SJ_API_KEY` and `SJ_SEC_KEY` must be set when server starts
   伺服器啟動時必須設定 `SJ_API_KEY` 和 `SJ_SEC_KEY`
4. **Public endpoints 公開端點** — `/api/v1/health` and `/api/v1/info` bypass auth even on non-localhost
   即使在非 localhost，`/api/v1/health` 和 `/api/v1/info` 也不需認證

### Unix Domain Socket (UDS) Issues Unix Domain Socket 問題

On macOS/Linux, the server can listen on both TCP and a Unix domain socket simultaneously.
在 macOS/Linux 上，伺服器可以同時監聽 TCP 和 Unix domain socket。

**Stale socket file 殘留的 socket 檔案:**

If the server crashes or is killed without cleanup, a stale `.sock` file may remain. The server automatically handles this:
如果伺服器當掉或被強制終止而未清理，可能殘留 `.sock` 檔案。伺服器會自動處理：
- If no process is listening on the socket, the stale file is removed automatically
  若沒有行程監聽該 socket，殘留檔案會自動移除
- If another server instance is using the socket, it is left untouched
  若另一個伺服器實例正在使用該 socket，則不會動它

**Manual cleanup if needed 必要時手動清理:**
```bash
# Check if socket is live 檢查 socket 是否仍在使用
# If connection refused, safe to remove 若連線被拒絕，可安全移除
rm /path/to/shioaji.sock
```

**Permission denied 權限被拒:**

UDS sockets are created with mode `0600` (owner-only access). Ensure the client runs as the same user as the server.
UDS socket 以模式 `0600`（僅擁有者可存取）建立。請確保客戶端與伺服器以相同使用者執行。

### SSE Stream Connection Issues SSE 串流連線問題

**Stream disconnects immediately SSE 串流立即斷開:**

- Ensure you subscribe to at least one contract before connecting to the SSE events endpoint
  確保在連接 SSE 事件端點前至少訂閱一個合約
- Use `curl -N` (no buffering) to see events in real time
  使用 `curl -N`（無緩衝）即時查看事件

```bash
# 1. Subscribe first 先訂閱
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"contract":{"security_type":"STK","exchange":"TSE","code":"2330"},"quote_type":"Tick"}'

# 2. Then connect to SSE 再連接 SSE
curl -N http://localhost:8080/api/v1/stream/data
```

**No data received 沒有收到數據:**

- Verify the contract code and exchange are correct 確認合約代碼和交易所正確
- Check if trading hours are active (TWSE: 09:00-13:30) 確認是否在交易時段（台股：09:00-13:30）
- Use `/api/v1/health` to confirm server is running 使用 `/api/v1/health` 確認伺服器運行中

### Server Timeout Configuration 伺服器逾時設定

The default Solace request-reply timeout is 60 seconds. If backend responses are slow:
預設的 Solace 請求-回覆逾時為 60 秒。若後端回應緩慢：

```bash
# Increase timeout via env var (in milliseconds) 透過環境變數增加逾時（毫秒）
export SJ_TIMEOUT=120000  # 120 seconds
shioaji server start
```

---

## Reference 參考資料

- QA Forum 問答論壇: https://sjapi.tw/
- Official docs 官方文檔: https://sinotrade.github.io/qa/
