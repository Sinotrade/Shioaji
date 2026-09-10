# Server monitoring

Use the running Server's **Overview** for request trends, backend activity Radar and readiness; **Activity** for category/endpoint rates, latency and individual request summaries. **Subscriptions** shows logical subscriptions and their quote-type distribution. Expand a row's **Details** for its requested topic, or **Connection & topic details** for physical stream evidence. Both start collapsed. The Contract cell displays the API's `symbol`, not a full Contract V2 object.

This measures one Server instance, not standalone Python processes, the entire broker, or every machine connection. Use the existing Server address and authentication from [HTTP_API.md](HTTP_API.md). Monitoring adds no authentication or trading permission. Check `/openapi.json` for installed support; a missing monitoring route on an older Server does not diagnose authentication failure.

## Diagnose before changing capture

1. Read settings and select a request source, origin and range. Start with `incoming` + `user`; use `backend` or `gateway` for upstream requests. These are separate measurements of potentially the same operation: compare sources, never add them.
2. Inspect rates, errors/timeouts, current in-flight count and latency. Quantiles are histogram estimates in microseconds (up to 25% relative bucket width), not precise benchmarks. In-flight counts describe now even for historical queries. Individual request summaries are not distributed traces.
3. Compare logical subscription items with stream items. Multiple symbols may share a wildcard/prefix. `pending` means a local subscribe call was accepted, not broker acknowledgement; `receiving` proves receipt. Quiet markets alone do not prove failure. Historical connections are not current subscriptions. Overlapping physical-topic five-second rates must not be summed.
4. Check `history_incomplete`, `coverage`, `dropped`, `persistence_error`, `partial` and `collecting` before concluding. Missing/disabled intervals and partial points are not zero traffic. Empty request summaries may mean recording was off. Retained stream counts while collection is stopped are previous observations, not current zero traffic.

Overview's Radar measures backend functions with the same range/origin, independently of request-chart category/endpoint filters. Activity Radar follows its selected source. Five axes group functions; seven split paper Order and Portfolio. All axes share a scale. Sparse/zero activity is legitimate and values are never padded. Charts expose details on hover; category colors have legends. Quota is broker-reported bytes used/limit, not an inferred connection quota.

## API contract

All routes below use `/api/v1/monitor`. The unreleased predecessor routes are removed, not aliases. Storage and the shared collector remain unchanged; this API does not introduce OpenTelemetry.

| Method | Suffix | Result |
|---|---|---|
| GET | `/metrics` | Endpoint counts/errors/latency, bounded series, coverage and persistence status |
| GET | `/requests` | Report with paginated individual request summaries |
| GET | `/subscriptions` | Global logical totals/distribution and a filtered page, without physical snapshots |
| GET | `/streams` | Current physical-topic/connection evidence; historical rows opt-in |
| GET / PATCH | `/settings` | Read or deeply partial update of nested capture/storage settings |
| POST | `/streams/sessions` | Create a server-issued stream-statistics session |
| PUT / DELETE | `/streams/sessions/{id}` | Renew an existing session / release that session only |

### Request queries

`/metrics` and `/requests` share:

- `source=incoming|backend|gateway`, default `incoming`.
- `origin=user|dashboard|background|all`, default `user`.
- `window=5m|15m|1h|6h|24h`, default `15m`; alternatively supply **both** `from` and `to` as ISO 8601 timestamps with timezones. The explicit pair is exclusive with `window`; `from < to`, end exclusive.
- Exact normalized `category` and `endpoint` filters.
- Request pagination: `limit=1..1000` (default 100), `offset=0..10000`, `sort=newest|slowest|errors` (default `newest`).

Responses include the resolved `range.from` / `range.to`. Reuse that pair without `window` while paging to freeze the interval; narrow the range beyond the offset bound. Aggregate source buckets are one second, so subsecond boundaries may include a whole source bucket; request summaries use exact timestamps. Charts contain at most 600 buckets.

```sh
curl --fail --get "$SHIOAJI_SERVER_URL/api/v1/monitor/metrics" \
  --data-urlencode 'source=incoming' \
  --data-urlencode 'origin=user' \
  --data-urlencode 'window=15m' \
  --data-urlencode 'category=order'
```

Custom monitoring clients may send `X-Shioaji-Activity: dashboard` for analytics attribution, not authorization. Built-in monitoring queries receive dashboard attribution automatically.

### Subscriptions and streams

`/subscriptions?type=tick&search=2330` filters the returned logical items. `total`, `market_data`, `trade_accounts` and `by_type` are independent of filtering/pagination. `matched` is the filtered item count; `items` is the page. Use these values for totals/radial charts, rather than fetching every page or adding physical topics. Global market/trade totals use the registries' full counts; the item snapshot is capped at 2,048 entries, so `by_type` and `matched` are incomplete when `partial=true`. Check `partial` / `unavailable` before treating the distribution as complete. Trade-account subscriptions are counted separately from market-data types.

`/streams` defaults to current connections. Set `history=true` to include retired/historical evidence; `search` filters topic text. Its `total` is the row count after the history choice, before search; `matched` is after search. Rows represent topic/connection pairs, not distinct symbols. Both endpoints support `limit=1..500` (default 100), `offset=0..10000`, and `search` up to 256 bytes.

Stream reports expose `collecting` and `since` (ISO timestamp of the count session's start, or null before one exists). The first viewer of a new session resets message counts/rates. A retained `since` while not collecting describes the previous session; historical, paused or unavailable evidence must not be presented as fresh zeroes.

## Capture and storage

Change capture or create a stream session only when the user's task authorizes it. Defaults:

```json
{"capture":{"metrics":true,"requests":false,"streams":"auto"},"storage":{"flush_seconds":1800,"retention_days":7,"max_mb":1024}}
```

All three capture controls are independent. `streams` accepts `off|auto`: auto permits on-demand collection but does not itself start it. PATCH is deeply partial: `{"capture":{"requests":true}}` changes only recording. Set metrics and requests false to stop request capture; set streams off to disable stream statistics. Existing history remains queryable. Storage bounds: `flush_seconds` 1–86400, `retention_days` 1–90, `max_mb` 1–10240. Despite the field name, **max_mb is MiB: 1 MiB = 1,048,576 bytes**, preserving existing limits. The API cannot choose a disk path. Persisted settings/history retain their existing format and are reused.

Stream-statistics session lifecycle:

1. POST `/streams/sessions` with no client-selected identifier. Keep the opaque returned `id`, `expires_in_seconds` (15) and `renew_after_seconds` (5).
2. PUT `/streams/sessions/{id}` at the returned renewal interval only while details are expanded, visible and unpaused. Renewal does not create a missing/expired session. A 404 requires a new POST if observation is still wanted; off returns an explicit conflict, not a successful inactive session.
3. DELETE that session when collapsed, hidden, paused, exiting or unmounted. Each viewer releases only its own session; other viewers remain active. Expiry handles failed cleanup. At most 64 viewers are admitted. No session operation unsubscribes market data.

The last session's release/expiry stops receipt statistics. Turning streams off revokes sessions and invalidates current physical-state confidence; new receipt evidence can reestablish receiving after reenable and a new session. The disabled receipt path performs an atomic flag load and returns without topic copying, queue admission or matching. Lifecycle/request telemetry remain separate costs: this is not literal zero overhead.

Settings updates apply at runtime and request asynchronous save. Check `last_saved_ms` and `persistence_error` when durability matters; successful PATCH is not proof of completed disk write. A native background worker handles Parquet load/save, capacity flushes and retention; graceful shutdown attempts a bounded final flush. Bounded admission may drop observations instead of delaying trading. Crashes/forced shutdown can lose unsaved data; this is diagnostic telemetry, not a lossless audit log.

Summaries retain normalized endpoints, method, source/origin, timestamps, duration and outcome—not bodies, credentials, query strings or account identifiers. Corrupt/oversized segments and exhausted historical-query budgets produce incomplete history; narrow the range and retain warnings. Verify with health/info reads or controlled fixtures. Never replay orders merely to populate charts.
