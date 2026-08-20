# Enriched Market Data 即時加值資料

Enriched market data is computed in real time by the quote engine from raw index/constituent feeds. It reuses the regular streaming subscription call — `api.subscribe(contract, quote_type=...)` — with dedicated `QuoteType` values. Without a callback, each event default-prints its repr; otherwise register a per-type callback (decorator or traditional) or pull from a receiver. HTTP uses **dedicated lifecycle routes per capability**, not the generic `/stream/subscribe`.

即時加值資料是行情引擎依原始指數／成分股行情即時運算的加值產物，沿用一般即時行情的 `api.subscribe(contract, quote_type=...)`，各有專屬 `QuoteType`。未設 callback 時事件以 repr 預設印出；否則用各型別的 callback（decorator 或傳統式）或 receiver 接收。HTTP 走**各能力專屬的 lifecycle 路由**，不是通用 `/stream/subscribe`。

> Realtime `QuoteType.KBar` is regular per-stock streaming — see [STREAMING.md](STREAMING.md). Market-wide signal alerts are [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md).
> 即時 KBar 屬一般證券即時行情，見 [STREAMING.md](STREAMING.md)；全市場訊號見 [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md)。

## Table of Contents 目錄

- [Capability Matrix 能力矩陣](#capability-matrix-能力矩陣)
- [Delivery Matrix 接收管道](#delivery-matrix-接收管道)
- [Constraints 約束規則](#constraints-約束規則產生程式前必查)
- [Minimal Examples 最小範例](#minimal-examples-最小範例)
- [Python Callbacks 行情回調](#python-callbacks-行情回調)
- [Attributes Reference 屬性參考](#attributes-reference-屬性參考)
- [Response and Decision Summary 回應與決策摘要](#response-and-decision-summary-回應與決策摘要)

## Capability Matrix 能力矩陣

| QuoteType | Contract target 訂閱標的（強制檢查） | Supported scope 支援範圍 | Cadence 推送頻率 |
|---|---|---|---|
| `CalculatedIndex` | Index 指數 | only `IX0001` 加權, `IX0043` 櫃買 | multiple per second 一秒可多筆 |
| `IndexContribution` | Index 指數 | only `IX0001`, `IX0043` | once per second 每秒一次 |
| `IndustryContribution` | Index 指數 | only `IX0001`, `IX0043` | once per second 每秒一次 |

## Delivery Matrix 接收管道

| QuoteType | Callback (traditional / decorator) | Receiver | HTTP subscribe (POST `/api/v1/…`) | SSE channel (GET `/api/v1/stream/data/…`) |
|---|---|---|---|---|
| `CalculatedIndex` | `set_on_calculated_index_callback` / `@api.on_calculated_index()` | `get_calculated_index_receiver()` | `/stream/subscribe/calculated_index` `{"index":<StreamContract>}` | `calculated_index` |
| `IndexContribution` | `set_on_index_contribution_callback` / `@api.on_index_contribution()` | `get_index_contribution_receiver()` | `/stream/subscribe/index_contribution` `{"index":…,"ranking":"top10"}` | `index_contribution` |
| `IndustryContribution` | `set_on_industry_contribution_callback` / `@api.on_industry_contribution()` | `get_industry_contribution_receiver()` | `/stream/subscribe/industry_contribution` `{"index":<StreamContract>}` | `industry_contribution` |

`<StreamContract>` = `{"security_type":"IND","exchange":"TSE","code":"IX0001","target_code":null}`.

## Constraints 約束規則（產生程式前必查）

- **Target enforced 標的強制**: each `QuoteType` only accepts the contract type listed in the Capability Matrix's "Contract target" column. A mismatched contract raises (e.g. `calculated index requires IND contract`).
  各 `QuoteType` 依能力矩陣「訂閱標的」欄強制檢查，帶錯直接報錯。
- **`ranking`**: required (keyword-only) for `QuoteType.IndexContribution`; passing it with any other `quote_type` raises. Closed set: `ContributionRanking.Top10/Abs10/Positive25/Negative25`, wire values `top10/abs10/positive25/negative25`.
  `ranking` 僅限且必填於 `QuoteType.IndexContribution`，其他 `quote_type` 帶了就報錯；值域封閉。
- **`intraday_odd` / `version`**: rejected for every enriched type. 所有加值型別一律拒絕。
- **CLI unsupported**: `shioaji data stream` rejects enriched types; Python and HTTP only.
  CLI 不支援即時加值資料，僅 Python／HTTP 可用。
- **HTTP subscribe response** is `{"success": bool, "message": str}` (`CapabilitySubscriptionResponse`) — there is **no `subscription` field**. Do not reuse the generic `/stream/subscribe` response shape in clients.
  HTTP 訂閱回應沒有 `subscription` 欄位，不要沿用通用 `/stream/subscribe` 的回應形狀。
- **Unsubscribe**: HTTP posts the same body to `/stream/unsubscribe/{capability}`; Python calls `api.unsubscribe(...)` with the same arguments.
  取消訂閱：HTTP 相同 body 打對應 unsubscribe 路由；Python 同參數呼叫 `api.unsubscribe(...)`。

## Minimal Examples 最小範例

```python
taiex = api.contracts.get("IX0001")
api.subscribe(taiex, quote_type=sj.QuoteType.CalculatedIndex)
api.subscribe(
    taiex,
    quote_type=sj.QuoteType.IndexContribution,
    ranking=sj.ContributionRanking.Top10,                        # required here only
)
api.subscribe(taiex, quote_type=sj.QuoteType.IndustryContribution)
```

```bash
curl -X POST localhost:8080/api/v1/stream/subscribe/calculated_index -H 'Content-Type: application/json' \
  -d '{"index":{"security_type":"IND","exchange":"TSE","code":"IX0001","target_code":null}}'
curl -N localhost:8080/api/v1/stream/data/calculated_index
```

## Python Callbacks 行情回調

```python
from shioaji import CalculatedIndex, IndexContribution, IndustryContribution

# Decorator syntax 裝飾器語法
@api.on_calculated_index()
def on_calculated_index(idx: CalculatedIndex):
    print(idx)

@api.on_index_contribution()
def on_index_contribution(ic: IndexContribution):
    print(ic)

@api.on_industry_contribution()
def on_industry_contribution(ind: IndustryContribution):
    print(ind)

# Setter syntax 設定器語法（equivalent 等同）
api.set_on_calculated_index_callback(on_calculated_index)
api.set_on_index_contribution_callback(on_index_contribution)
api.set_on_industry_contribution_callback(on_industry_contribution)

# Clear 清除
api.clear_on_calculated_index_callback()
api.clear_on_index_contribution_callback()
api.clear_on_industry_contribution_callback()
```

Async (`ShioajiAsync`) uses the same names with `async def` callbacks. Receivers: `get_calculated_index_receiver()` / `get_index_contribution_receiver()` / `get_industry_contribution_receiver()` with `await recv()` / `try_recv()`.
Async 同名、callback 改 `async def`。Receiver 三個同名 getter，`await recv()`／`try_recv()`。

## Attributes Reference 屬性參考

Python objects have `to_dict()` and full reprs. Field names verified from live captures; SSE JSON uses the same names. Dates are `YYYY/MM/DD` strings, times `HH:MM:SS.ffffff` strings.
Python 物件皆有 `to_dict()` 與完整 repr，欄位名皆經實測；SSE JSON 欄位名相同。日期／時間皆為字串。

### CalculatedIndex Attributes 自算指數屬性

```python
idx.code               # str: Index code 指數代碼
idx.date               # str: Date 日期
idx.time               # str: Time 時間
idx.open               # float: Open 開盤指數
idx.high               # float: High 最高指數
idx.low                # float: Low 最低指數
idx.close              # float: Latest value 最新指數
idx.total_amount       # int: Cumulative turnover 累計成交金額 (NTD)
idx.price_chg          # float: Price change 漲跌
idx.pct_chg            # float: Percent change 漲跌幅 (%)
idx.simtrade           # bool: Simulated trading 試撮
```

### IndexContribution Attributes 指數貢獻屬性

```python
ic.ranking             # ContributionRanking: 排行方式
ic.code                # str: Index code 指數代碼
ic.date                # str: Date 日期
ic.time                # str: Time 時間
ic.entries             # list[dict]: 貢獻排行清單，每筆
                       #   {code, price, reference, price_chg, pct_chg, points}
ic.simtrade            # bool: Simulated trading 試撮
```

### IndustryContribution Attributes 產業貢獻屬性

```python
ind.code               # str: Index code 指數代碼
ind.date               # str: Date 日期
ind.time               # str: Time 時間
ind.entries            # list[dict]: 產業貢獻清單，每筆 {category, points}
                       #   category = exchange industry code 交易所產業類別代碼
ind.simtrade           # bool: Simulated trading 試撮
ind.index_close        # float: Latest index value 最新指數
ind.index_price_chg    # float: Index change 指數漲跌；entries 的 points 加總＝此值
```

## Response and Decision Summary 回應與決策摘要

| Operation | Python | HTTP | Agent decision |
|---|---|---|---|
| Subscribe enriched | `api.subscribe(contract, quote_type=…)`; events default-print unless a callback/receiver is attached | `POST /stream/subscribe/{capability}` → `{success, message}` | `success=false` or an exception → check contract target type, supported codes (`IX0001`/`IX0043`), and `ranking` rules before retrying. No output after subscribe usually means market closed, not failure. |
| Consume events | per-type callback / decorator / receiver | `GET /stream/data/{channel}` SSE; heartbeat ≠ data | Parse `event:` name first. Heartbeat-only outside trading hours is normal, not broken. |
| Unsubscribe | same args to `api.unsubscribe(...)` | same body to `/stream/unsubscribe/{capability}` | Treat `success=true` as accepted. |
