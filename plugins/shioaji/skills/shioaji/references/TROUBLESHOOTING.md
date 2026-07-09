# Troubleshooting 常見問題

Common issues and solutions for Shioaji (package: `shioaji`, import: `import shioaji as sj`).
Shioaji 常見問題與解決方案（套件名稱：`shioaji`，引入方式：`import shioaji as sj`）。

Use [MIGRATION.md](MIGRATION.md) when an error comes from deprecated Python idioms. Use the matching functional reference when the next step depends on HTTP response shape, order status, or SSE behavior.

---

## Market Data 行情資料相關

### Historical data returns empty 歷史行情回傳空資料

**Problem 問題:** Historical market data or snapshot calls return no rows, empty arrays, or empty vectors in Python, CLI, or HTTP clients.
Python、CLI 或 HTTP client 查歷史行情或 snapshot 時，沒有資料列、回空陣列或欄位向量是空的。

This is often caused by exhausted market-data traffic quota, and can also be a valid no-data response. Do not retry blindly. First check usage, then identify the response shape:
這常見原因是行情流量額度已滿，也可能是合法的 no-data response。不要直接盲目重試，先檢查用量，再確認 response shape：

```bash
# CLI: check API usage first
# CLI：先檢查 API 用量
shioaji auth usage -f json

# HTTP: check usage from the running server
# HTTP：從執行中的 server 檢查用量
curl http://localhost:8080/api/v1/auth/usage
```

If `remaining_bytes` is `0` or near zero, treat the empty historical response as a quota/traffic issue before changing query parameters. Wait for quota reset, reduce request size/frequency, cache historical results, or contact SinoPac support if the quota should not be exhausted.
如果 `remaining_bytes` 為 `0` 或接近 0，請先把歷史行情空回應視為流量/額度問題，不要先改查詢參數。等額度重置、降低請求量與頻率、快取歷史結果；若額度不應該耗盡，再聯絡永豐客服。

Use restriction rule: when traffic exceeds the limit, market data queries `ticks`, `snapshots`, and `kbars` return empty values while other features are not affected. Traffic resets at 8:00 AM on each trading day.
使用限制規則：若流量超過限制，行情查詢 `ticks`、`snapshots`、`kbars` 會回傳空值，其他功能不受影響。流量於開盤日早上 8:00 重置。

Real-time subscriptions are different: streaming subscriptions do **not** consume traffic quota. If SSE only receives heartbeat or Python callbacks receive no ticks, diagnose subscription payload, trading hours, contract identity, or continuous-futures `target_code` instead of blaming historical-data quota first.
即時行情訂閱不同：即時行情訂閱**不會**佔用流量。若 SSE 只有 heartbeat 或 Python callback 沒收到 tick，請先排查訂閱 payload、交易時段、合約身分或連續月期貨的 `target_code`，不要先歸因為歷史行情流量額度。

- Python `api.ticks(...)` returns `Ticks`; empty means `len(ticks.ts) == 0`.
  `api.ticks(...)` 回 Python `Ticks`；空資料表示 `len(ticks.ts) == 0`。
- `POST /api/v1/data/ticks` returns column-oriented JSON; empty means `datetime: []` and matching empty vectors, not necessarily top-level `[]`.
  `POST /api/v1/data/ticks` 回 column-oriented JSON；空資料通常是 `datetime: []` 和其他欄位向量為空，不一定是 top-level `[]`。
- CLI `shioaji data ticks -f json` follows the HTTP/server shape; non-JSON output may transpose to rows, so an empty result may print no rows.
  CLI `shioaji data ticks -f json` 遵循 HTTP/server shape；非 JSON 輸出可能轉成 row，因此空結果可能顯示為沒有資料列。
- Python `api.kbars(...)` returns `KBars`; empty means `len(kbars.ts) == 0`.
  `api.kbars(...)` 回 Python `KBars`；空資料表示 `len(kbars.ts) == 0`。
- `POST /api/v1/data/kbars` returns column-oriented JSON; empty means `datetime: []` with empty OHLCV vectors.
  `POST /api/v1/data/kbars` 回 column-oriented JSON；空資料通常是 `datetime: []` 和 OHLCV 欄位為空。
- CLI `shioaji data kbars -f json` follows the HTTP/server shape; non-JSON output may transpose to rows, so an empty result may print no rows.
  CLI `shioaji data kbars -f json` 遵循 HTTP/server shape；非 JSON 輸出可能轉成 row，因此空結果可能顯示為沒有資料列。
- Python `api.snapshots(...)`, CLI `shioaji data snapshots`, and HTTP `/api/v1/data/snapshots` return a top-level list/array; traffic exhaustion or no matching snapshot data can produce an empty result.
  Python `api.snapshots(...)`、CLI `shioaji data snapshots` 與 HTTP `/api/v1/data/snapshots` 回 top-level list/array；流量耗盡或沒有符合 snapshot 資料時可能回空結果。
- `scanner`, `credit_enquire`, and `short_stock_sources` can also return top-level empty arrays when no records match, but the official traffic-exceeded empty-value warning specifically names `ticks`, `snapshots`, and `kbars`.
  `scanner`、`credit_enquire`、`short_stock_sources` 沒有符合資料時也可能回 top-level 空陣列，但官方「流量超限回空值」警示明確點名的是 `ticks`、`snapshots`、`kbars`。

**Check 檢查項目:**

1. **Traffic quota / usage 流量額度 / 用量** — Check `api.usage()`, `shioaji auth usage`, or `GET /api/v1/auth/usage` first. If `remaining_bytes` is exhausted, empty historical responses are expected until quota is available again.
   先查 `api.usage()`、`shioaji auth usage` 或 `GET /api/v1/auth/usage`。如果 `remaining_bytes` 已耗盡，歷史行情回空是預期現象，需等額度恢復。
2. **Request rate 次數限制** — Market data queries (`credit_enquires`, `short_stock_sources`, `snapshots`, `ticks`, `kbars`) share a 50 calls / 5 seconds limit. Intraday `ticks` queries are limited to 10 calls; intraday `kbars` queries are limited to 270 calls. If exceeded, wait at least one minute before retrying.
   行情查詢（`credit_enquires`、`short_stock_sources`、`snapshots`、`ticks`、`kbars`）總次數為 5 秒 50 次；盤中 `ticks` 查詢不得超過 10 次，盤中 `kbars` 查詢不得超過 270 次。若超限，至少等待一分鐘再重試。
3. **Trading day 交易日** — Weekends, holidays, or future dates can have no historical rows.
   週末、休市日或未來日期可能沒有歷史資料。
4. **Supported historical range 支援區間** — Historical ticks/K-bars are only available from the supported start dates in [MARKET_DATA.md](MARKET_DATA.md#historical-data-periods-歷史資料可查詢區間).
   歷史 ticks/K-bars 只支援 [MARKET_DATA.md](MARKET_DATA.md#historical-data-periods-歷史資料可查詢區間) 內列出的起始日期之後資料。
5. **KBar request window K 棒單次窗口** — If KBar returns `400: Kbars date range must not exceed 30 days`, split backfill into chunks of 29 days or less and write them into a local data manager, preferably as partitioned Parquet. This is not a "latest 30 days only" rule. During market hours, query only today's changing K-bars and upsert that mutable partition instead of repeatedly querying long ranges.
   如果 K 棒回 `400: Kbars date range must not exceed 30 days`，請把回補切成 29 天以內的小段，寫進本地 data manager，底層建議用 partitioned Parquet。這不是「只能查最近 30 天」的規則。盤中只查今天會變動的 K 棒並 upsert 當天 mutable partition，不要反覆查長區間。
6. **Contract identity 合約身分** — Verify `security_type`, `exchange`, and `code` with `GET /api/v1/data/contracts/{code}?security_type=...` before querying data.
   查資料前先用 `GET /api/v1/data/contracts/{code}?security_type=...` 確認 `security_type`、`exchange`、`code`。
7. **Expired futures 過期期貨** — For old futures history, use continuous contracts such as `TXFR1` / `TXFR2`; an expired concrete code may return no rows.
   查已過期期貨歷史資料時使用 `TXFR1` / `TXFR2` 這類連續合約；已過期的實際合約代碼可能沒有資料。
8. **Time filters 時間條件** — `RangeTime` can legitimately return empty if the interval has no trades; `LastCount` with `last_cnt <= 0` is invalid.
   `RangeTime` 區間內沒有成交時會合法回空；`LastCount` 的 `last_cnt <= 0` 是無效參數。

```bash
# Check contract first 先確認合約
curl "http://localhost:8080/api/v1/data/contracts/2330?security_type=STK"

# Then query a known trading day 再查一個已知交易日
curl -X POST http://localhost:8080/api/v1/data/ticks \
  -H "Content-Type: application/json" \
  -d '{
    "contract": {"security_type": "STK", "exchange": "TSE", "code": "2330"},
    "date": "2026-05-27",
    "query_type": "LastCount",
    "last_cnt": 10
  }'
```

If the response is still empty after these checks, treat it as no available data for that query and tell the user which condition was checked. Only escalate to connection/auth/server troubleshooting when Python raises an exception, the CLI exits with an error, HTTP returns an error, or the response is malformed.
若檢查後仍為空，請把它當成該查詢沒有可用資料，並告訴使用者已檢查哪些條件。只有在 Python 拋例外、CLI 以錯誤退出、HTTP 回 error 或 response 格式異常時，才轉往連線、認證或 server 問題排查。

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
order = sj.FuturesOrder(
    action=sj.Action.Buy,
    price=0,  # MKT ignores price 市價單忽略價格
    quantity=1,
    price_type=sj.FuturesPriceType.MKT,
    order_type=sj.OrderType.IOC,  # MKT must use IOC / FOK; MKP / LMT accept ROD too 僅 MKT 須 IOC/FOK
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

# Stocks — MKT accepts ROD too
# 股票 — MKT 可搭配 ROD
order = sj.StockOrder(
    action=sj.Action.Buy,
    price=0,
    quantity=1,
    price_type=sj.StockPriceType.MKT,
    order_type=sj.OrderType.ROD,  # Or IOC / FOK 也可用 IOC / FOK
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

order = sj.StockOrder(
    action=sj.Action.Buy,
    price=price,
    quantity=1,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    account=api.stock_account
)
```

### No callback for pre-market reservation orders 預約單沒有立即回報

Pre-market reservation orders do not trigger order/deal callbacks immediately. Reservation orders are released at 08:30 on each trading day, and callbacks are triggered then.
盤前預約單不會立即觸發委託/成交回報。預約單會在每個交易日 08:30 放單，屆時才會觸發委託回報。

Do not infer callback failure only because a pre-market reservation order produced no callback before 08:30. Confirm the order/trade state with `list_trades()` / `/api/v1/order/trades`, and for HTTP order events make sure `POST /api/v1/auth/subscribe_trade` was called per account in production.
不要因為 08:30 前沒有 callback 就判定 callback 壞掉。請用 `list_trades()` / `/api/v1/order/trades` 確認委託狀態；HTTP 委託回報在正式環境還要確認每個帳戶都已呼叫 `POST /api/v1/auth/subscribe_trade`。

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
def on_tick(tick):
    print(tick)

api.subscribe(
    api.Contracts.Stocks["2330"],
    quote_type=sj.QuoteType.Tick
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

### Sign data is timeout 登入簽章逾時

`Sign data is timeout` means the login request exceeded its valid execution window, or the client clock is too far from the server clock.
`Sign data is timeout` 表示登入請求超過有效執行時間，或 client 系統時間與 server 時間相差太大。

**Check 檢查項目:**

1. Sync the OS clock first. This applies to Python clients and to machines running `shioaji server start` for JS/Go/Rust/C#/Java clients.
   先校準作業系統時間。Python client 要校時；JS/Go/Rust/C#/Java 使用的 `shioaji server start` 那台機器也要校時。
2. If the machine clock is correct but login is slow, increase Python `receive_window` from the default 30000 ms.
   若時間正確但登入過慢，Python 可把 `receive_window` 從預設 30000 ms 調高。
3. For HTTP/CLI/server clients, restart the server after fixing the machine time so the login flow uses the corrected clock.
   HTTP/CLI/server client 在修正系統時間後重啟 server，讓登入流程使用正確時間。

---

## Environment 環境設定

### Server starts but login/order setup is wrong 伺服器可啟動但登入或下單設定不對

The CLI/server auto-loads `.env` from the working directory. Before `shioaji server start`, check the complete server environment instead of only checking key/secret:
CLI/server 會從工作目錄自動載入 `.env`。在執行 `shioaji server start` 前，請檢查完整 server 環境，不要只檢查 key/secret：

```env
SJ_API_KEY=your_api_key
SJ_SEC_KEY=your_secret_key
SJ_CA_PATH=/path/to/Sinopac.pfx
SJ_CA_PASSWD=your_ca_password
SJ_PRODUCTION=false
```

- Use `SJ_PRODUCTION=false` while testing language clients unless the user explicitly wants real trading.
  測試語言 client 時使用 `SJ_PRODUCTION=false`，除非使用者明確要正式交易。
- Missing or expired CA (`SJ_CA_PATH`, `SJ_CA_PASSWD`) blocks production orders, even if login and market data work.
  CA 未設定或過期會阻擋正式下單，即使登入與行情查詢可用。
- Check `GET /api/v1/info` for `simulation`, and `GET /api/v1/health` for token/contract/CA status before diagnosing strategy code.
  排查策略程式前，先用 `GET /api/v1/info` 檢查 `simulation`，用 `GET /api/v1/health` 檢查 token、contract、CA 狀態。
- On Windows, write CA paths with `/` or escaped `\\`; a single backslash path copied into Python strings or `.env` can be misread.
  Windows 的 CA 路徑請使用 `/` 或跳脫後的 `\\`；單一反斜線路徑放進 Python 字串或 `.env` 可能被誤讀。

See [PREPARE.md](PREPARE.md) for the full `.env` and certificate flow.

### Installation 安裝

Install the CLI/package as `shioaji` and import it as `shioaji`:
CLI/套件名稱與 Python 引入名稱都使用 `shioaji`：

```bash
# Install with uv 使用 uv 安裝
uv tool install shioaji

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

## Contracts 商品檔相關

### Contract not found or stale 商品找不到或資料過舊

Contract files are time-sensitive. Use these update windows when diagnosing stale or missing contracts:
商品檔有更新時段。排查商品檔過舊或找不到商品時，先用以下更新時間判斷：

| Time 時間 | Update 更新內容 |
|-----------|------------------|
| 07:50 | Futures contracts 期貨商品檔 |
| 08:00 | Full market contracts 全市場商品檔 |
| 14:45 | Futures night-session contracts 期貨夜盤商品檔 |
| 17:15 | Futures night-session contracts 期貨夜盤商品檔 |

**Check 檢查項目:**

1. If a contract is missing near an update window, reload contracts before changing code.
   若商品在更新時段附近找不到，先重新載入商品檔，不要先改程式。
2. Python can use `contracts_timeout`, `contracts_cb`, `fetch_contract=False`, and `api.fetch_contracts(contract_download=True)` to control or observe contract loading.
   Python 可用 `contracts_timeout`、`contracts_cb`、`fetch_contract=False` 與 `api.fetch_contracts(contract_download=True)` 控制或觀察商品檔載入。
3. HTTP/CLI/other language clients get contracts from the running server. Check `GET /api/v1/health` for `contract_count` and restart `shioaji server start` if the server loaded stale contracts.
   HTTP/CLI/其他語言 client 使用執行中 server 的商品檔。用 `GET /api/v1/health` 檢查 `contract_count`；若 server 載入的是舊商品檔，重啟 `shioaji server start`。
4. Expired concrete futures codes disappear from `api.Contracts`; use continuous contracts such as `TXFR1` / `TXFR2` for long historical futures queries.
   到期的實際期貨代碼會從 `api.Contracts` 消失；長期歷史期貨查詢請用 `TXFR1` / `TXFR2` 這類連續合約。

---

## Connection 連線相關

### Login reused a token that expires too soon 登入重用了快到期 token

Python `login()` uses the local token pool by default. When `force_refresh=False`, the client looks for a reusable local token slot for the same API key, secret, simulation mode, and VPN mode. A slot is reusable only when it is not locked by a live process, the JWT `exp` is still in the future, and the token has at least 5 hours remaining. Before reuse, the client connects with the cached `client_name` and verifies the cached token with `auth/usage`; if that verification fails, the local slot is removed and login falls back to a fresh backend token request.
Python `login()` 預設會使用 local token pool。`force_refresh=False` 時，client 會找同一組 API key、secret、simulation、VPN mode 的可重用 token slot。可重用條件是：沒有被其他 live process 鎖住、JWT `exp` 尚未過期、且至少還有 5 小時有效期。重用前 client 會用 cached `client_name` 連線，並透過 `auth/usage` 驗證 cached token；驗證失敗時會移除 local slot，改走 fresh backend token login。

This means a successful `login()` does not always mean "a token freshly minted now". If the pool contains a valid cached token created earlier today, a new process can reuse it. For example, a token minted 18 hours ago still has about 6 hours left, so it passes the 5-hour local reuse threshold but expires in less than 8 hours from the new process start. That is expected token-pool behavior, not a backend 24-hour-token violation.
這代表成功 `login()` 不一定等於「現在剛簽發的新 token」。如果 token pool 裡有今天稍早建立的有效 cached token，新 process 可能會重用它。例如 18 小時前簽發的 token 還剩約 6 小時，會通過本地 5 小時重用門檻，但從新 process 啟動時間算起不到 8 小時就會過期。這是 token-pool 行為，不是 backend 違反 24 小時 token 的規則。

Another edge case is backend-side invalidation after a previous process disconnects normally. The local token file can still contain a JWT whose `exp` is within 24 hours, but the backend Solace monitor may have expired the server-side token/relay record after the disconnect. In that case the reuse probe should fail at `auth/usage`, the local slot is invalidated, and the client performs fresh login automatically. This is different from a temporary rate-limit ban, where the backend rejects even fresh login for the ban window.
另一個邊界情境是前一個 process 正常斷線後的 backend-side invalidation。Local token file 仍可能保存一個 JWT `exp` 還在 24 小時內的 token，但 backend Solace monitor 可能已在斷線後讓 server-side token/relay record 過期。這種情況下，重用 probe 應該會在 `auth/usage` 失敗，client 會 invalidated local slot 並自動 fresh login。這和暫時 rate-limit ban 不同；ban 期間 backend 會連 fresh login 都拒絕。

Use `force_refresh=True` when the requirement is: "after this login call succeeds, the session token should be a newly issued backend token with a fresh 24-hour lifetime" (except when the account/IP is temporarily banned or the credentials/version/IP/permission are rejected).
當需求是「這次 `login()` 成功後，session token 必須是 backend 新簽發、從現在起有 fresh 24 小時效期的 token」時，使用 `force_refresh=True`（例外是帳號/IP 正在暫時 ban，或 credentials/version/IP/permission 被拒）。

```python
import shioaji as sj

api = sj.Shioaji()
accounts = api.login(
    api_key="YOUR_KEY",
    secret_key="YOUR_SECRET",
    force_refresh=True,
)
```

```python
api = sj.ShioajiAsync()
accounts = await api.login(
    api_key="YOUR_KEY",
    secret_key="YOUR_SECRET",
    force_refresh=True,
)
```

Use this for long-running jobs that must not inherit a token created by an earlier process. Do not use it as a retry loop for `操作異常，請1分鐘後再重新登入`; that message is a temporary backend ban. `force_refresh=True` bypasses token-pool reuse, but it still respects the login failure cache, so repeated calls during the cached ban window return locally instead of hitting the backend again. Wait first, then fix request rate or reconnect behavior.
長時間執行的工作若不能繼承前一個 process 建立的 token，請用這個方式。不要把它用成 `操作異常，請1分鐘後再重新登入` 的重試迴圈；那是 backend 暫時 ban。`force_refresh=True` 會 bypass token-pool reuse，但仍會尊重 login failure cache，所以 cached ban window 內反覆呼叫會在本機直接回錯，不會再次打 backend。應先等待，再修正 request rate 或重連行為。

### 503 Response Triage: rate-limit ban vs yanked version

Do not treat every 503 the same. First branch on the response detail/message.
`503` can mean either a temporary rate-limit ban or a rejected client version;
the fixes are opposite.

不要把所有 503 當成同一種問題。先看 response detail/message 分流。
`503` 可能是暫時限流 ban，也可能是 client 版本被伺服器拒收；兩者修法不同。

| Symptom / detail | Cause | Fix |
|---|---|---|
| `操作異常，請1分鐘後再重新登入` | Temporary rate-limit ban. The account/IP has exceeded a request-rate guardrail, so the backend blocks the whole session path; even `login()` can return 503 during the ban window. | Stop retry loops. Wait at least one minute without sending more login/API requests, then reduce request rate, replace polling with streaming, batch/cache repeated queries, and add client-side backoff. |
| `Please update the version of shioaji ...` followed by `Not authenticated` on later calls | Version rejected by the server. Known bad yanked 1.5.x releases are not accepted; PyPI marks `1.5.0` and `1.5.1` yanked, and as of 2026-06-25 `1.5.2` is also yanked. | Upgrade to `shioaji==1.5.3`, then restart the Python process or `shioaji server` daemon and login again. |

| 症狀 / detail | 成因 | 修法 |
|---|---|---|
| `操作異常，請1分鐘後再重新登入` | 暫時限流 ban。帳號/IP 超過 request-rate 防護後，後端會擋住整個 session path；ban 期間連 `login()` 都可能回 503。 | 停止重試迴圈。至少一分鐘內不要再送 login/API request，再降低頻率、用 streaming 取代輪詢、批次/快取重複查詢，並加入 client-side backoff。 |
| `Please update the version of shioaji ...`，後續呼叫又出現 `Not authenticated` | 版本被伺服器拒收。已知有問題的 yanked 1.5.x 版本不被接受；PyPI 標記 `1.5.0`、`1.5.1` 為 yanked，截至 2026-06-25 `1.5.2` 也被標記為 yanked。 | 升級到 `shioaji==1.5.3`，然後重啟 Python process 或 `shioaji server` daemon，再重新登入。 |

```bash
# uv project
uv add "shioaji==1.5.3"

# pip / existing environment
python -m pip install -U "shioaji==1.5.3"

# CLI tool install
uv tool install --force "shioaji==1.5.3"
```

Rate-limit ban guardrails include market-data queries (50 / 5 sec),
accounting queries (25 / 5 sec), and order operations (250 / 10 sec). These
limits are intentionally broad; correct Shioaji usage should stay far away from
them. Hitting a rate limit is a strong signal that the program's usage pattern
is wrong, not that a normal strategy needs to run closer to the limit. A ban is
not solved by trying `login()` again every few seconds; repeated login attempts
can keep the ban alive. Fix the usage pattern instead: keep one logged-in
process/server session, subscribe to streaming market data instead of polling,
cache historical data and account snapshots, and avoid `update_status()` loops
when order/deal callbacks or SSE can provide active reports.

限流 ban 的常見 guardrail 包含行情查詢 5 秒 50 次、帳務查詢 5 秒 25 次、
委託操作 10 秒 250 次。這些限制目前設得很寬；正確 Shioaji 用法應該離
rate limit 很遠。觸發 rate limit 是程式使用模式有明顯問題的訊號，不是
合理策略需要貼近限制執行。ban 不是每幾秒重打 `login()` 就能解；反覆登入
可能讓 ban 延長。要修的是使用方式：維持一個已登入 process/server
session、用 streaming 訂閱取代輪詢、快取歷史行情與帳務快照，並避免用
`update_status()` 迴圈取代主動委託/成交回報或 SSE。

### Rate limit exceeded 超過流量限制

For 503 responses, first use [503 Response Triage](#503-response-triagerate-limit-ban-vs-yanked-version) above. This section is the general limit reference.
遇到 503 時先看上方 [503 Response Triage](#503-response-triagerate-limit-ban-vs-yanked-version) 分流；本節是一般限制參考。

**Limits 限制:**

| Category 類別 | Limit 限制 |
|---------------|------------|
| Quote query 行情查詢 | 50 / 5 sec |
| Accounting 帳務 | 25 / 5 sec |
| Orders 委託 | 250 / 10 sec |
| Connections 連線 | 5 per person |
| Daily logins 每日登入 | 1000 times |

**Solution 解決方案:**
- Treat the limit hit as a usage bug first; inspect loops, reconnect paths,
  polling, and error retries.
  先把觸發限制視為使用方式錯誤；檢查迴圈、重連路徑、輪詢和錯誤重試。
- Use callbacks or SSE streaming instead of polling.
  用 callback 或 SSE streaming 取代輪詢。
- Cache or batch repeated reads; add delay/backoff only after the workflow is
  corrected.
  快取或批次處理重複查詢；先修正 workflow，再加 delay/backoff。

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

The Shioaji HTTP server (`shioaji server start`) provides REST and SSE endpoints. Below are common issues.
Shioaji HTTP 伺服器（`shioaji server start`）提供 REST 和 SSE 端點。以下是常見問題。

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

### Response field mismatch 欄位名稱對不上

Do not reuse Python object attributes as HTTP/CLI/client fields. Use the matching functional reference first, and fetch `/openapi.json` only when exact installed-server fields are required.
不要直接把 Python 物件屬性當成 HTTP/CLI/語言 client 欄位；先查對應功能型 reference，只有需要確認安裝版本精確欄位時才查 `/openapi.json`。

- Python `api.snapshots()` exposes `snap.ts`; HTTP `POST /api/v1/data/snapshots` returns `datetime`.
  Python `api.snapshots()` 有 `snap.ts`；HTTP `POST /api/v1/data/snapshots` 回 `datetime`。
- Python callbacks and HTTP SSE JSON do not share all field names. HTTP stock tick SSE uses fields such as `date`, `time`, `total_volume`, `price_chg`, and `pct_chg`.
  Python callback 與 HTTP SSE JSON 欄位不完全相同。HTTP 股票 tick SSE 會使用 `date`、`time`、`total_volume`、`price_chg`、`pct_chg` 等欄位。
- HTTP order responses are nested `Trade { contract, order, status, deals }`; JS/Go/Rust/C#/Java clients must not expect flat top-level `order_id`, `seqno`, or `ordno`.
  HTTP 下單回應是巢狀 `Trade { contract, order, status, deals }`；JS/Go/Rust/C#/Java client 不要期待 top-level `order_id`、`seqno`、`ordno`。

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
3. **Verify env vars 確認環境變數** — `SJ_API_KEY` and `SJ_SEC_KEY` must be set when server starts; production orders also need `SJ_CA_PATH` and `SJ_CA_PASSWD`
   伺服器啟動時必須設定 `SJ_API_KEY` 和 `SJ_SEC_KEY`；正式下單也需要 `SJ_CA_PATH` 和 `SJ_CA_PASSWD`
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

- Ensure you subscribe to at least one contract before connecting to the SSE endpoint, and branch on `success` in `SubscriptionResponse`
  確保在連接 SSE 端點前至少訂閱一個合約，並檢查 `SubscriptionResponse.success`
- Use `curl -N` (no buffering) to see events in real time
  使用 `curl -N`（無緩衝）即時查看事件

```bash
# 1. Subscribe first 先訂閱
curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"STK","exchange":"TSE","code":"2330","quote_type":"Tick"}'

# 2. Then connect to SSE 再連接 SSE
curl -N http://localhost:8080/api/v1/stream/data
```

**Only heartbeat / no market data 只有 heartbeat 或沒有行情:**

- Verify the contract code and exchange are correct 確認合約代碼和交易所正確
- Check if trading hours are active (TWSE: 09:00-13:30) 確認是否在交易時段（台股：09:00-13:30）
- Use `/api/v1/health` to confirm server is running 使用 `/api/v1/health` 確認伺服器運行中
- For futures continuous-month aliases `TXFR1` / `TXFR2`, first resolve the contract and copy `target_code` into the subscribe body. Regular futures codes do not need this.
  期貨連續月 alias `TXFR1` / `TXFR2` 要先查合約並把 `target_code` 放進訂閱 body；一般期貨代碼不需要。
- For order events in production, call `POST /api/v1/auth/subscribe_trade` once per account before opening `/api/v1/stream/data/order_event`. In simulation, `subscribe_trade` is a no-op success and is not required.
  正式環境的委託回報要先對每個帳戶呼叫一次 `POST /api/v1/auth/subscribe_trade`，再打開 `/api/v1/stream/data/order_event`；simulation 模式下這是 no-op success，不需要呼叫。

```bash
# Continuous futures alias example 連續月範例
curl "http://localhost:8080/api/v1/data/contracts/TXFR1?security_type=FUT"

curl -X POST http://localhost:8080/api/v1/stream/subscribe \
  -H "Content-Type: application/json" \
  -d '{"security_type":"FUT","exchange":"TAIFEX","code":"TXFR1","target_code":"TXFF6","quote_type":"Tick"}'
```

### Server Timeout Configuration 伺服器逾時設定

The default Solace request-reply timeout is 60 seconds. If backend responses are slow:
預設的 Solace 請求-回覆逾時為 60 秒。若後端回應緩慢：

```bash
# Increase timeout via env var (in milliseconds) 透過環境變數增加逾時（毫秒）
export SJ_TIMEOUT=120000  # 120 seconds
shioaji server start
```
