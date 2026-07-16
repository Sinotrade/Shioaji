# Contract V2 商品檔

Use this reference for Shioaji 1.7 Contract V2 lookup, typed contract info, lazy loading, and update notifications. New code should use `api.contracts`; `api.Contracts` is a 1.5-compatible legacy facade.
本文件說明 Shioaji 1.7 Contract V2 的查詢、型別化商品資訊、按需載入與更新通知。新程式使用 `api.contracts`；`api.Contracts` 是相容 1.5 的舊介面。

---

## Mental Model 心智模型

Contract V2 separates small identity records from larger, type-specific detail records:

- **Base contract** identifies a product with `security_type`, `region`, `exchange`, `code`, and optional `target_code`.
- **Info** adds the flat, typed fields for STK, IND, FUT, OPT, or WRT.
- Orders, quote subscriptions, snapshots, ticks, and K-bars accept the Base contract directly. Fetch Info only when the application needs descriptive or rule fields such as `reference`, limits, multiplier, or tick bands.
- Login does not require downloading every product detail. The first lookup downloads only the needed dataset or shard and then reuses memory/disk cache.
- A contract update event marks the affected cache dirty. The next access refreshes it lazily; callers do not manually reload the contract files.

Contract V2 將小型的商品身分與較大的分型明細分開：登入不必先下載所有商品明細；第一次查詢才下載所需資料或 shard，之後使用記憶體／磁碟快取。收到商品更新事件後，內部會將受影響快取標記為過期，下一次存取再按需更新。

Choose the narrowest lookup that matches the task:

| Need | Python | HTTP | CLI |
|------|--------|------|-----|
| Known exchange/master code | `api.contracts.get("2330")` | `GET /contracts/2330` | `shioaji contracts get 2330` |
| Typed details for one base | `api.contracts.info(base)` | `GET /contracts/2330/info` | `shioaji contracts info 2330` |
| One futures root | `api.contracts.futures("TXF")` | `GET /contracts/futures?root=TXF` | `shioaji contracts futures --root TXF` |
| One option root | `api.contracts.options("TXO")` | `GET /contracts/options?root=TXO` | `shioaji contracts options --root TXO` |
| Warrants for an underlying | `api.contracts.warrants(underlying)` | `GET /contracts/warrants?underlying_code=2330` | `shioaji contracts warrants --underlying 2330` |
| Every base of one type | `api.contracts.list("STK")` | `GET /contracts?security_type=STK` | `shioaji contracts list --type STK` |

HTTP paths in this table are relative to `/api/v1/data`. There is no endpoint that aggregates STK, IND, FUT, OPT, and WRT into one response. Omitting pagination returns all **Base contracts for the selected `security_type` only**; use pagination for large UI lists.

---

## Python API

### Base lookup and typed info

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

tsmc = api.contracts.get("2330")
if tsmc is None:
    raise LookupError("contract 2330 not found")

print(tsmc.security_type, tsmc.region, tsmc.exchange, tsmc.code)
stock_info = api.contracts.info(tsmc)
print(stock_info.name, stock_info.currency, stock_info.reference)
```

`get(code, region=None)` searches the region's security types and returns a `BaseContract` or `None`. Codes are exchange/master codes. For example, the Taiwan weighted index is `IX0001`; the pre-1.7.0 index code `001` no longer resolves (returns 404 / `None`).

`info(base)` returns a typed object:

| `security_type` | Python info type | Examples of type-specific fields |
|-----------------|------------------|---------------------------------|
| `STK` | `StockInfo` | `currency`, `unit`, `day_trade`, `reference`, margin/short fields |
| `IND` | `IndexInfo` | `reference`, `open_time`, `close_time` |
| `FUT` | `FuturesInfo` | `root`, `delivery_month`, `multiplier`, `tick_rule`, limits |
| `OPT` | `OptionInfo` | `root`, `strike_price`, `option_right`, `expiry_weekday`, `tick_rule` |
| `WRT` | `WarrantInfo` | `underlying_code`, `call_put`, `strike_price`, `expiry_date` |

Info objects expose `base` plus typed fields. Their `repr()` omits fields whose value is `None`; `dict()` may retain those keys. Do not infer HTTP JSON shape from the Python object—the HTTP info response is flat and uses `security_type` as its discriminator.

For the complete field list of these Info objects (StockInfo / FuturesInfo / OptionInfo / IndexInfo / WarrantInfo), with types and bilingual descriptions, see [CONTRACT_FIELDS.md](CONTRACT_FIELDS.md).

Do not call `info()` merely to place an order or subscribe to quotes. Pass the Base returned by `get()` directly. If order-price logic needs `reference` or limits, query Info for that calculation but still use the Base as the order contract:

```python
base = api.contracts.get("2330")
if base is None:
    raise LookupError("contract 2330 not found")

info = api.contracts.info(base)  # Only needed here to choose a price.
if info is None:
    raise LookupError("contract info 2330 not found")
order = sj.StockOrder(
    action=sj.Action.Buy,
    price=info.reference,
    quantity=1,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
)
trade = api.place_order(base, order)
```

### List all bases of one type

```python
stocks = api.contracts.list(sj.SecurityType.Stock)
indexes = api.contracts.list("IND")
```

`list(kind, region=None)` returns all Base contracts for exactly one selected type and region. It does not download all Info rows and does not combine multiple security types. Prefer `get`, `futures`, `options`, or `warrants` when the caller does not truly need the complete base list.

### Futures

```python
txf_chain = api.contracts.futures("TXF")
txfr1 = api.contracts.get("TXFR1")

if txfr1 is not None:
    print(txfr1.code, txfr1.target_code)
    txfr1_info = api.contracts.info(txfr1)
    bands = api.contracts.tick_bands(txfr1_info)
```

- `futures(root, region=None)` returns the typed `FuturesInfo` rows for one root.
- `futures_by_underlying(base)` finds futures whose `underlying_code` matches the supplied base contract.
- `futures_roots(region=None)` returns `(root, name)` pairs.
- Continuous aliases such as `TXFR1` and `TXFR2` carry the currently resolved real contract in `target_code`. HTTP streaming clients must copy it into quote-subscription requests; ordinary futures codes do not need it.
- Do not hard-code futures tick sizes. Use `tick_rule`/`tick_bands()` because bands may change by effective date.

### Options

```python
roots = api.contracts.option_roots()
txo_chain = api.contracts.options("TXO")

calls = [row for row in txo_chain if row.option_right == sj.OptionRight.Call]
```

`options(root, region=None)` is intentionally root-based because option Info is sharded by root. Use `option_roots()` to discover available roots without loading every option shard. Unlike futures, options have no `options_by_underlying` — query them by `root` only.

### Warrants

```python
tsmc = api.contracts.get("2330")
if tsmc is None:
    raise LookupError("underlying 2330 not found")

tsmc_warrants = api.contracts.warrants(tsmc)
underlyings = api.contracts.warrant_underlyings()
```

Warrant Info is sharded by underlying. Calling `api.contracts.info()` on a WRT Base contract raises `WarrantInfoRequiresUnderlying`; resolve the underlying and call `warrants(underlying)` instead. `warrant_underlyings()` returns `(BaseContract, name)` pairs.

### Tick bands

```python
future = api.contracts.futures("TXF")[0]
bands = api.contracts.tick_bands(future)

# A known rule string is also accepted.
bands = api.contracts.tick_bands(future.tick_rule)
```

Use tick-band metadata for FUT/OPT price validation. Do not copy a price-band table into application code; exchange rules can change.

### Async client

The async client exposes the same namespace and operations. Await every lookup:

```python
api = sj.ShioajiAsync()
await api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

base = await api.contracts.get("IX0001")
if base is not None:
    info = await api.contracts.info(base)

txo_chain = await api.contracts.options("TXO")
```

---

## HTTP API

All Contract V2 query endpoints use `GET`. Authenticate exactly as described in [HTTP_API.md](HTTP_API.md).

```bash
# Exact code; security_type is optional and can narrow ambiguous codes.
curl "http://localhost:8080/api/v1/data/contracts/2330?region=TW&security_type=STK"

# Flat typed info; security_type is the OpenAPI discriminator.
curl "http://localhost:8080/api/v1/data/contracts/2330/info?region=TW&security_type=STK"

# All STK bases, or a one-based page for a large UI.
curl "http://localhost:8080/api/v1/data/contracts?security_type=STK&region=TW"
curl "http://localhost:8080/api/v1/data/contracts?security_type=STK&region=TW&page=1&page_size=500"

# Shard-aware queries.
curl "http://localhost:8080/api/v1/data/contracts/futures?root=TXF&region=TW"
curl "http://localhost:8080/api/v1/data/contracts/options?root=TXO&region=TW"
curl "http://localhost:8080/api/v1/data/contracts/warrants?underlying_code=2330&region=TW"
```

The list response contains `contracts`, `security_type`, `region`, and `total`. `page`, `page_size`, and `max_page` appear only for a paged request. A Base record contains only identity fields; request `/info` or a type-specific collection when details are needed.

The `/info` response is a flat tagged union. Shared identity and type-specific fields are at the same JSON level; there is no nested `base` object. For example:

```json
{
  "security_type": "STK",
  "region": "TW",
  "exchange": "TSE",
  "code": "2330",
  "target_code": null,
  "name": "台積電",
  "currency": "TWD",
  "reference": 1000.0
}
```

For TW stock Info, a missing source currency is normalized to `TWD` in both Python and HTTP. Boolean and integer fields remain JSON booleans and numbers, not strings.

See [HTTP_API.md](HTTP_API.md) for all filters, root-discovery endpoints, and the exact OpenAPI schema.

---

## Contract Change Notifications 商品變動通知

Python handles Contract V2 events internally. Once an application accesses a type/shard, Shioaji subscribes to the relevant update stream; an event safely dirties the affected Info cache, and the next lookup refreshes it lazily. Application code should not install a Contract callback or manually reload data.

HTTP and CLI expose passive notifications for applications that need to refresh a screen or rerun a lookup when reference prices, limits, margin data, or other contract details change:

```bash
curl -N "http://localhost:8080/api/v1/stream/data/contract_event?region=TW&security_type=STK"

shioaji contracts watch --region TW --type STK
```

The SSE event name is `contract_event`, and its `id` is the logical `event_id`. Public JSON contains only application-facing change metadata:

```json
{
  "event_id": "opt-generation",
  "action": "CHECK",
  "region": "TW",
  "security_type": "OPT",
  "published_at": "2026-07-15T07:50:05+08:00",
  "base_changed": false,
  "info_changed": true,
  "info_scope": "SHARDS",
  "info_shards": ["TXO"]
}
```

`info_scope` is `ALL`, `SHARDS`, or `null`; `info_shards` identifies affected roots/underlyings when the scope is `SHARDS`. Transport chunk fields and internal hashes are not exposed. The event is a change signal, not a replacement for querying the contract. On receipt, call the relevant GET endpoint again. Filters are optional; omit them only when the consumer truly needs all Contract V2 change notifications.

There is no public Contract preload, reload, or readiness/status endpoint in the normal workflow. A query waits for the required dataset and returns it or an error.

---

## CLI Quick Reference

```bash
shioaji contracts get 2330 --type STK
shioaji contracts info IX0001 --type IND
shioaji contracts list --type STK --page 1 --page-size 500
shioaji contracts futures --root TXF
shioaji contracts options --root TXO --right C
shioaji contracts warrants --underlying 2330
shioaji contracts futures-roots
shioaji contracts option-roots
shioaji contracts warrant-underlyings --include-name
shioaji contracts tick-bands <RULE> --type FUT
shioaji contracts watch --region TW --type STK
```

`contracts list` returns all bases of the selected type unless `--page` or `--page-size` is supplied. See [CLI.md](CLI.md) for every filter and output option.

---

## Legacy 1.5 Compatibility

Existing 1.5-style code can continue through the compatibility facade while it is migrated:

The facade returns the new `*Info` objects (e.g. `api.Contracts.Stocks["2330"]` yields a `StockInfo`) and emits a `DeprecationWarning` that is hidden by default.

```python
stock = api.Contracts.Stocks["2330"]
stock = api.Contracts.Stocks.TSE["2330"]
future = api.Contracts.Futures.TXF.TXFR1
```

Do not generate attribute access from a prefixed code such as `api.Contracts.Stocks.TSE.TSE2330`; `TSE2330` is not a valid attribute key. New 1.7 examples should use `api.contracts` so lookup behavior, lazy loading, regions, and typed Info are explicit.

---

## Decision and Error Summary

| Result | Meaning and next action |
|--------|-------------------------|
| Python `get(...)` returns `None` / HTTP 404 | No matching Base contract in that region/type. Verify exchange/master code and optional `security_type`; do not silently substitute a different product. |
| Empty list | The selected root, underlying, filters, or page has no matching rows. It is not proof that all Contract V2 data is unavailable. |
| `WarrantInfoRequiresUnderlying` | Resolve the underlying and use `warrants(underlying)` or `/contracts/warrants?underlying_code=...`. |
| Continuous future has `target_code` | Use that real code for HTTP quote subscription; retain the alias for the user's logical selection. |
| Contract event received | Re-query only the data the application needs. Python cache invalidation is automatic. |
| A field is absent/`None` | Treat it as unavailable unless the documented type supplies a fallback (TW stock currency becomes `TWD`). Do not coerce arbitrary missing fields. |
