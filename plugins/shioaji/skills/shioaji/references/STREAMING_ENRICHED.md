# Enriched Market Data 即時加值資料

Enriched market data is computed from raw index and constituent feeds. Use
`api.index_components(index)` for the authoritative constituents query. For a
point-in-time official index value, use the existing `api.snapshots([index])`
query. Realtime enriched values reuse `api.subscribe(contract, quote_type=...)`
with dedicated `QuoteType` values. HTTP uses dedicated query and lifecycle
routes, not generic `/stream/subscribe`.

即時加值資料由指數與成分股行情運算而成。成分股權威狀態使用
`api.index_components(index)`；指數當下值使用既有
`api.snapshots([index])` 官方報價查詢。即時加值資料沿用
`api.subscribe(contract, quote_type=...)`。HTTP 使用各能力專屬的查詢與生命週期路由。

> Realtime `QuoteType.KBar` is regular per-stock streaming; see
> [STREAMING.md](STREAMING.md). Market-wide signals are in
> [STREAMING_SIGNALS.md](STREAMING_SIGNALS.md).

## Capability Matrix 能力矩陣

| QuoteType | Required target | Supported scope | Cadence |
|---|---|---|---|
| `CalculatedIndex` | Index | `IX0001/TSE`, `IX0043/OTC` | multiple per second |
| `IndexContribution` | Index | `IX0001/TSE`, `IX0043/OTC` | 1 second |
| `IndustryContribution` | Index | `IX0001/TSE`, `IX0043/OTC` | 1 second |
| `IndexComponents` | Index | `IX0001/TSE`, `IX0043/OTC` | market/group 1 second; within-group ranking 5 seconds |

The first three rows are the released 1.7.3 stream surface and remain
compatible. `IndexComponents` query and projections are available in 1.7.4.

## Authoritative Queries 權威查詢

```python
taiex = api.contracts.get("IX0001")

components = api.index_components(taiex)
official_index = api.snapshots([taiex])[0]

# Async client uses the same method names.
components = await async_api.index_components(taiex)
```

These calls do not subscribe. `index_components()` performs one authoritative
request without cache, retry, pagination, or callbacks and returns the complete
constituent and industry-group snapshot. Python financial fields are `Decimal`;
ISO fields become native `date`, `time`, and timezone-aware `datetime` values.

HTTP query routes:

```text
POST /api/v1/data/index_components
```

`index_components` body is `{"contract": <ContractRequest>}`. The response
contains root `contract`, session/reference context, `market_phase`,
`refresh_state`, classification and weight method, `total_amount`, complete
`entries`, and complete industry `groups`.

Each constituent entry contains a `BaseContract`, category, price/reference,
change/percentage/points, exact weight and activity allocations,
price/trading/data status, and optional `source_at`. Each group contains its
name/count, equal- and reference-weighted performance, contribution points,
weight/activity allocations, advance/decline/unchanged counts, and breadth.

## Streaming Delivery Matrix 串流接收管道

| QuoteType | Callback | Receiver | HTTP lifecycle | Dedicated SSE |
|---|---|---|---|---|
| `CalculatedIndex` | `on_calculated_index` | `get_calculated_index_receiver` | `calculated_index` | `calculated_index` |
| `IndexContribution` | `on_index_contribution` | `get_index_contribution_receiver` | `index_contribution` | `index_contribution` |
| `IndustryContribution` | `on_industry_contribution` | `get_industry_contribution_receiver` | `industry_contribution` | `industry_contribution` |
| `IndexComponents` | `on_index_components` | `get_index_components_receiver` | `index_components` | `index_components` |

HTTP lifecycle routes are
`POST /api/v1/stream/{subscribe|unsubscribe}/{capability}`. Dedicated SSE routes
are `GET /api/v1/stream/data/{capability}`. The aggregate
`GET /api/v1/stream/data` continues to emit every subscribed capability.

## Subscription Constraints 約束規則

- The index must be Contract V2 `TW/TSE/IND IX0001` or `TW/OTC/IND IX0043`.
  Unsupported identity is rejected before broker work.
- `ranking` is required and keyword-only for legacy
  `QuoteType.IndexContribution`; other quote types reject it.
- `projection` is required and keyword-only for
  `QuoteType.IndexComponents`; other quote types reject it.
- Derived quote types reject `intraday_odd` and `version`.
- Subscribe and unsubscribe use the same `(index, projection)` pair. Repeated
  operations are idempotent and projections are independent.
- The CLI `shioaji data stream` does not expose enriched streams; use Python or
  HTTP/SSE.
- HTTP subscribe/unsubscribe returns `{"success": bool, "message": str}`.

`IndexComponentsProjection` is an immutable tagged value built through one of
three target-specific factories:

```python
IndexComponentsProjection.group_metric(metric)
IndexComponentsProjection.component_ranking(metric, order, limit, group=None)
IndexComponentsProjection.group_ranking(metric, order, limit)
```

Component metrics are `Contribution`, `PctChange`, `Weight`, `Amount`, and
`AmountShare`. Group metrics are `Contribution`, `EqualWeightPerformance`,
`WeightedPerformance`, `Weight`, `Amount`, `AmountShare`, and `Breadth`.
Orders are `Desc`, `Asc`, `AbsDesc`, `PositiveDesc`, and `NegativeAsc`.
Projection values expose read-only `kind`, `target`, `metric`, `order`,
`limit`, and `group` properties, so callbacks can inspect a dynamic
projection without parsing its `value` or topic suffix.

The published streaming matrix is exact; other combinations are rejected:

| Factory/target | Metric | Supported order / limit |
|---|---|---|
| `group_metric` | all 7 group metrics | no order or limit; emits every group |
| `component_ranking` | `Contribution`, `PctChange` | `Desc/10`, `AbsDesc/10`, `PositiveDesc/25`, `NegativeAsc/25` |
| `component_ranking` | `Weight`, `Amount` | `Desc/10` |
| `component_ranking` | `AmountShare` | not published |
| `component_ranking(group=...)` | `Contribution` | `AbsDesc/10` |
| `component_ranking(group=...)` | `Amount` | `Desc/10` |
| `component_ranking(group=...)` | `PctChange`, `Weight`, `AmountShare` | not published |
| `group_ranking` | `Contribution`, `EqualWeightPerformance`, `WeightedPerformance`, `Breadth` | `AbsDesc/10` |
| `group_ranking` | `Weight`, `Amount` | `Desc/10` |
| `group_ranking` | `AmountShare` | not published |

`AmountShare` ranking is omitted because it orders identically to `Amount`
within one snapshot. Python projection factories reject unpublished
combinations immediately with `ValueError`; `subscribe()` and `unsubscribe()`
also repeat the validation before any broker operation. Every Python validation
error includes the supported order/limit pairs.
HTTP subscribe and unsubscribe validate the same matrix and return `400` with
the same supported-pairs message. Invalid enum/tagged-union shapes are request
validation errors rather than subscription attempts.

Within-group topics exist only for group category IDs present in that index's
authoritative `index_components()` snapshot. Use `snapshot.groups` to discover
the valid IDs; the category is the stable topic identity and its display name
does not enter the subscription key.

## Query-to-Stream Projection Mapping 查詢至串流投影映射

The authoritative query is a superset of every streaming projection. Applying
a projection to one `index_components()` snapshot produces the
stream-equivalent initial state for that projection; the financial metrics are
already calculated in the query and must not be recomputed from prices.

Public stream `value` maps from query fields as follows:

| Projection metric | Query field or conversion |
|---|---|
| component `Contribution` | `entry.points` |
| component `PctChange` | `entry.pct_chg` |
| component `Weight` | `Decimal(entry.reference_weight_ppm) / 10_000` percent |
| component `Amount` | `Decimal(entry.total_amount)` |
| component `AmountShare` | `Decimal(entry.amount_share_bps) / 100` percent |
| group `Contribution` | `group.points` |
| group `EqualWeightPerformance` | `group.equal_weight_pct_chg` |
| group `WeightedPerformance` | `group.weighted_pct_chg` |
| group `Weight` | `Decimal(group.reference_weight_ppm) / 10_000` percent |
| group `Amount` | `Decimal(group.total_amount)` |
| group `AmountShare` | `Decimal(group.amount_share_bps) / 100` percent |
| group `Breadth` | `Decimal(group.breadth_bps) / 100` percent |

`group_metric(metric)` maps every query group to `{category, name, item_count,
value}` using the selected row above. A ranking projection uses this exact
pipeline:

1. Start with all query entries for a component ranking or all query groups for
   a group ranking. When component `group` is present, first keep entries whose
   `category` equals it.
2. Map the selected metric to `value` using the table above.
3. For `PositiveDesc`, keep only `value > 0`; for `NegativeAsc`, keep only
   `value < 0`. The other orders do not apply a sign filter.
4. Sort `Desc` and `PositiveDesc` by `value` descending, `Asc` and
   `NegativeAsc` by `value` ascending, and `AbsDesc` by `abs(value)` descending.
   Break equal sort keys by component `contract.code` or group `category`,
   ascending.
5. Keep the first `limit` rows.

Component ranking rows use `entry.contract.code` as `code` and copy category,
price/reference/change, reference weight, and status fields from the query
entry. Group rows copy category, name, and item count. Event-level contract and
session/reference context have the same meanings as their query counterparts.
This mapping describes initialization and reconciliation semantics; it does not
change the published projection matrix above.

## Python Examples

```python
import shioaji as sj

taiex = api.contracts.get("IX0001")
api.subscribe(taiex, quote_type=sj.QuoteType.CalculatedIndex)
api.subscribe(
    taiex,
    quote_type=sj.QuoteType.IndexContribution,
    ranking=sj.ContributionRanking.Top10,
)
api.subscribe(taiex, quote_type=sj.QuoteType.IndustryContribution)
api.subscribe(
    taiex,
    quote_type=sj.QuoteType.IndexComponents,
    projection=sj.IndexComponentsProjection.component_ranking(
        sj.IndexComponentsComponentMetric.PctChange,
        sj.IndexComponentsRankingOrder.AbsDesc,
        10,
    ),
)

# Highest absolute contributors within industry category 24.
api.subscribe(
    taiex,
    quote_type=sj.QuoteType.IndexComponents,
    projection=sj.IndexComponentsProjection.component_ranking(
        sj.IndexComponentsComponentMetric.Contribution,
        sj.IndexComponentsRankingOrder.AbsDesc,
        10,
        group="24",
    ),
)

# Industries whose contribution has the largest absolute magnitude.
api.subscribe(
    taiex,
    quote_type=sj.QuoteType.IndexComponents,
    projection=sj.IndexComponentsProjection.group_ranking(
        sj.IndexComponentsGroupMetric.Contribution,
        sj.IndexComponentsRankingOrder.AbsDesc,
        10,
    ),
)
```

```python
from shioaji import IndexComponentsGroupUpdate, IndexComponentsRankingUpdate

@api.on_index_components()
def on_index_components(
    update: IndexComponentsRankingUpdate | IndexComponentsGroupUpdate,
):
    print(update)

# Equivalent setter and clear operations:
api.set_on_index_components_callback(on_index_components)
api.clear_on_index_components_callback()
```

With `bind=False`, the callback receives only `update`. With `bind=True`, the
existing context is prepended: `(context, update)`. Async clients use the same
names with `async def`. Pull consumers use `get_index_components_receiver()`
and `await recv()` or `try_recv()`.

HTTP example:

```bash
curl -X POST localhost:8080/api/v1/stream/subscribe/index_components \
  -H 'Content-Type: application/json' \
  -d '{"index":{"security_type":"IND","exchange":"TSE","code":"IX0001","target_code":null},"projection":{"kind":"ranking","target":"group","metric":"contribution","order":"abs_desc","limit":10}}'
curl -N localhost:8080/api/v1/stream/data/index_components
```

## IndexComponents Event Models

The callback/SSE event is either `IndexComponentsRankingUpdate` or
`IndexComponentsGroupUpdate`. Both contain:

```text
contract, projection, date, time, calculated_at, reference_date,
market_phase, simtrade
```

Component-ranking updates add ordered `entries` with code, category, selected
metric `value`, price/reference, price and percentage change, reference weight,
and status fields. Group updates add `unit` and ordered
`{category, name, item_count, value}` groups. The projection determines whether
the unit is points, percent, weight, currency amount, amount share, or breadth.
Complete group metrics contain every group; group rankings contain at most the
requested limit.

Each event is a complete replacement for one `(index, projection)`. There is no
delta, generation, sequence, replay, retained-message, or cross-projection
atomicity guarantee. `event: index_components` is used by both aggregate and
dedicated SSE; `projection` identifies the variant.

If immediate state is required:

1. Subscribe first.
2. Call `index_components()`.
3. Keep whichever state has the newer `calculated_at`.

Subscription does not secretly issue a query. Query is the authoritative
recovery path after reconnect or an SSE gap.

## Legacy 1.7.3 Stream Models

The existing `CalculatedIndex`, `IndexContribution`, and
`IndustryContribution` callbacks, receivers, subscriptions, SSE routes, event
shapes, and topic bytes remain compatible. `ContributionRanking` still has
`Top10`, `Abs10`, `Positive25`, and `Negative25`. These legacy stream events are
independent from the new index-components update classes.

## Response and Decision Summary 回應與決策摘要

| Operation | Decision |
|---|---|
| Query components | `api.index_components(index)` is one authoritative request. `state_not_ready`/503 is retryable; 429 means the daily data-usage quota is exhausted. Do not poll continuously. |
| Subscribe | Check contract identity and required `ranking`/`projection` first. `success=false` is not a subscription. |
| No events | Heartbeat-only outside trading hours is normal. It does not prove a failed subscription. |
| Reconnect/gap | Re-query `index_components()` and replace local state; do not expect replay. |
| Unsubscribe | Send the same index plus ranking/projection; `success=true` means accepted. |
