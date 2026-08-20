# Combo Orders 組合單

This document covers Shioaji combo contracts, native futures combo market
data, combo orders, TAIFEX leg ordering, net-price calculation, and status
confirmation. Combo orders are production-only; simulation/paper mode does
not support placing or cancelling combo orders.

## Mental Model 心智模型

A combo order has three layers and two compatible contract-construction modes:

```text
Managed ComboContract (new)
  legs[0]: BaseContract                 # canonical first leg, no action
  legs[1]: BaseContract                 # canonical second leg, no action
  Shioaji validates TAIFEX shape/order and derives leg actions at order time

Directed ComboContract (legacy-compatible)
  legs[0]: ComboBase(action=Buy/Sell, contract fields...)
  legs[1]: ComboBase(action=Buy/Sell, contract fields...)
  the caller owns leg order and directions

ComboOrder
  action / price / quantity / price_type / order_type / octype / account /
  combo_type

ComboTrade
  contract + order + status
```

Exactly two homogeneous legs are required. Accept either two ordinary
`BaseContract`-compatible Contract V2 contracts or two `ComboBase` objects.
Reject a mixed `BaseContract + ComboBase` pair locally because it has two
conflicting authorities for leg direction.

Keep both modes behaviorally distinct:

- **Managed/Base mode:** validate that the two contracts form a TAIFEX-native
  combo and are already in canonical exchange order. Reject an invalid or
  reversed pair; do not silently reorder user input. At placement,
  `ComboOrder.action` is required and is the exchange-level `BS_Code`; derive
  both leg actions from it, `combo_type`, and canonical leg positions
  immediately before serializing the existing SW payload. Reject an omitted
  action instead of applying the legacy `Sell` default.
- **Directed/ComboBase mode:** preserve the established public API and wire
  behavior. Each `ComboBase.action` remains authoritative. Do not reorder legs
  or overwrite their actions from `ComboOrder.action`. The order-level action
  is semantically ignored in this mode: changing or omitting it must not change
  either leg's direction. It may remain in the serialized legacy payload only
  where required for wire compatibility. This path lets existing users run
  unchanged; SW/TAIFEX remains the final validator.

Use one internal normalized directed representation after validation so the SW
protocol does not need separate managed and legacy request formats.

## Required Fields 必填欄位

Fill these fields before sending a combo order:

- `ComboContract.legs`: exactly two homogeneous legs.
- Managed mode legs: two resolvable ordinary contracts. Resolve current
  Contract V2 Info by code before validating `root`, `delivery_date`, strike,
  and option right; a bare object whose Info cannot be resolved is invalid.
- Directed mode legs: two `ComboBase` values with explicit `Buy`/`Sell` and
  the established contract fields.
- `ComboOrder.action`: explicitly required for managed legs. It determines the
  exchange Buy/Sell side and therefore both derived leg actions. For directed
  legs it remains accepted for compatibility but is ignored semantically.
- `ComboOrder.price`: net combo limit price, not a per-leg price.
- `ComboOrder.quantity`: combo quantity; both legs use this quantity.
- `ComboOrder.price_type`: normally `FuturesPriceType.LMT` for combo orders.
- `ComboOrder.order_type`: must be legal for the product and session.
- `ComboOrder.octype`: usually `FuturesOCType.Auto` unless explicit
  open/close handling is required.
- `ComboOrder.account`: futures/options account. Python calls can omit it
  when `api.futopt_account` is available.
- `ComboOrder.combo_type`: optional when the validated managed shape has one
  unambiguous type. If supplied, it must equal the derived type; it does not
  override an incompatible pair. Keep legacy directed behavior compatible.

## Build Combo Contract 建立組合合約

Use two normal Contract V2 contracts for the managed mode. A combo is derived
from its legs; it is not a separate row in the contract file.

```python
near = api.contracts.get("TXFN6")
far = api.contracts.get("TXFO6")
if near is None or far is None:
    raise LookupError("futures contract not found")

combo_contract = api.contracts.combo(legs=[near, far])
print(combo_contract.code)  # TXFN6/O6
```

Invalid, mixed, or reversed legs raise `sj.ShioajiValueError`, the standard
Shioaji validation exception. It is also a Python `ValueError` subclass for
compatibility, but catch the precise public class when the distinction matters:

```python
try:
    api.contracts.combo(legs=[far, near])
except sj.ShioajiValueError as error:
    print(error)  # includes the expected canonical exchange order
```

The same managed futures `ComboContract` is used for orders and market data:

```python
api.subscribe(combo_contract, quote_type=sj.QuoteType.Tick)
ticks = api.ticks(combo_contract, date="2026-07-17")
snapshots = api.snapshots([combo_contract])
```

Never pass a native code such as `TXFL6/C7` as a public leg. The slash
form is an internal Solace/SW/DolphinDB transport key generated by Shioaji.
Public code provides two ordinary contracts in canonical order and lets
Shioaji validate and encode them.

Managed `ComboContract.code` exposes that derived read-only identity so
callback data can be mapped back to the structured contract. Directed
`ComboBase(action=...)` contracts are order-only and have no market-data
identity. For equal three-character
roots, the second leg omits the root: `TXFH6 + TXFI6 -> TXFH6/I6`. When the
roots differ, the complete second code remains: `MX4G6 + MXFH6 ->
MX4G6/MXFH6`. Tick and bid/ask callbacks put this value in `tick.code` and
`bidask.code`; keep the returned contracts as the source of truth instead of
parsing the slash string:

```python
combos = api.contracts.combo_futures(root="TXF")
combo_by_code = {combo.code: combo for combo in combos}

def on_bidask(exchange, bidask):
    combo = combo_by_code[bidask.code]
    print(combo.legs, bidask.bid_price, bidask.ask_price)
```

The physical Solace topics use the same identity:

```text
TIC/v1/FOP/*/TFE/{combo.code}
QUO/v1/FOP/*/TFE/{combo.code}
QUO/v2/FOP/*/TFE/{combo.code}   (QuoteType.Quote)
```

These topics explain callback identity and troubleshooting. Normal users pass
the structured `ComboContract` to `api.subscribe()`; Shioaji constructs the
topic.

HTTP exposes the same core-derived identity. Use `POST
/api/v1/data/contracts/combo` to validate one pair or `GET
/api/v1/data/contracts/combo/futures?root=TXF` to enumerate a family. Each
record contains `code` and structured `legs`; FOP SSE `data.code` maps directly
to that `code`. See [HTTP_API.md](HTTP_API.md#managed-combo-contracts) for the
request and response examples.

Discover managed futures combinations locally from Contract V2:

```python
combos = api.contracts.combo_futures(root="TXF")
```

`combo_futures` returns only managed/Base-mode `ComboContract` values. It does
not manufacture `ComboBase.action`, query SW for a separate combo contract
file, or return legacy directed contracts. Generate only pairs supported by
current contract Info and the TAIFEX family/order rules below. Quote/tick/
snapshot results reveal whether a valid native combination currently has data.

`api.contracts.combo(legs=...)` has no `region` argument: it derives region and
exchange from the legs and rejects cross-region or cross-exchange pairs.
`combo_futures(root, region=Region.TW)` does take `region`, defaulting to Taiwan,
because there are no input legs from which to infer it. Validation is dispatched
by `(region, exchange)` so future foreign-futures rules can reuse the public
interface without pretending TAIFEX ordering rules apply abroad. Until a market
validator is implemented, that market must fail clearly as unsupported.

The legacy directed constructor remains supported unchanged for combo order
APIs only. Subscription, ticks, and snapshot APIs require a managed/actionless
contract returned by `api.contracts.combo()` or `combo_futures()`:

```python
combo_contract = sj.ComboContract(
    legs=[
        sj.ComboBase(
            action=sj.Action.Buy,
            security_type=sj.SecurityType.Futures,
            exchange=sj.Exchange.TAIFEX,
            code="TXFG5",
            symbol="TXFG5",
            category="TXF",
            delivery_month="202607",
        ),
        sj.ComboBase(
            action=sj.Action.Sell,
            security_type=sj.SecurityType.Futures,
            exchange=sj.Exchange.TAIFEX,
            code="TXFH5",
            symbol="TXFH5",
            category="TXF",
            delivery_month="202608",
        ),
    ]
)
```

`ComboBase.from_contract()` remains a convenience for legacy code. Its
explicit action stays authoritative.

## TAIFEX Canonical Validation and Leg Actions

Apply these rules only to managed/Base-mode contracts. Validate with resolved
Contract V2 Info; do not infer expiry order from a contract-code string alone
or from `R1`/`R2` aliases. Normally compare the actual `delivery_date`. TMP
v2.18.8 sections 3.5.2 and 3.5.3 retain an otherwise legal time spread when
force majeure shifts both legs onto the same delivery date; for that tie only,
fall back to the original delivery month, week number, and expiry weekday.
Reject when metadata cannot establish a unique original order.

Common validation:

- Require exactly two different concrete TAIFEX contracts of the same security
  type. Reject continuous aliases and unresolved contracts.
- Require both legs to belong to the same TAIFEX combo family. Contract
  metadata is authoritative. A code prefix is only an encoding aid.
- Require the caller's legs to already match the canonical order below. Return
  a clear error that includes the expected order when reversed.
- Derive `combo_type` from the legal shape. An explicit mismatching type is an
  error.

Keep structural and temporal checks separate. Contract data refreshes daily.
A product that is no longer listed (e.g. after expiry) cannot be resolved, so
a combo containing it cannot be built — historical queries and subscriptions
for expired combos are therefore unavailable. Only `combo_futures` enumeration
filters by expiry (`delivery_date >= today`); order placement and subscription
rely on the exchange to reject ineligible contracts or sessions.

### Futures time spreads

- Standard monthly pair: require the same futures `root`, different delivery
  dates, near expiry first and far expiry second.
- Non-stock weekly pair: allow monthly/weekly, weekly/monthly, or weekly/weekly
  contracts only when metadata confirms the same underlying family. For the
  native futures encoding, `PP + T` uses the first two product characters plus
  `F` for monthly or `1/2/4/5` for weekly; for example `MXF`, `MX1`, `MX2`,
  `MX4`, and `MX5` are one MX family. Prefix equality alone is insufficient.
- Stock and ETF futures use their exact underlying/version family; require the
  same root and different delivery dates.
- Canonical order is always near first, far second. Native combo price is
  `far - near`.
- `ComboOrder.action=Buy` means sell near and buy far. `Sell` means buy near
  and sell far. The exchange buy/sell side is defined by the far leg.

`api.contracts.combo_futures(root=...)` must use the same validator as order
placement and quote encoding, so a generated combo cannot later fail because
the three code paths disagree about family or order.

#### Native combo bid/ask meaning

Read the order book as bids and asks for the **whole canonical combo**, not as
the near leg's order book. For a futures time spread whose canonical legs are
`[near, far]`, the native combo price is always `far - near` and may be
negative.

| Combo book side | Resting exchange action | Leg actions | What the consumer can do |
|---|---|---|---|
| `bid_price` / `bid_volume` | Buy the combo (`BS_Code=B`) | Sell near, buy far | A combo seller can hit this bid |
| `ask_price` / `ask_volume` | Sell the combo (`BS_Code=S`) | Buy near, sell far | A combo buyer can lift this ask |

Therefore `ComboOrder(action=Buy)` normally trades against the combo ask; it
does not mean buying the near leg. `ComboOrder(action=Sell)` normally trades
against the combo bid. A quote subscription selects neither direction: one
`BidAsk` subscription receives both sides, and `bidask.code` identifies the
canonical combo.

For example, with `[TXFH6, TXFI6]`, the book is quoted for
`TXFI6 - TXFH6`. Its synthetic comparison is:

```text
combo bid = TXFI6.bid - TXFH6.ask
combo ask = TXFI6.ask - TXFH6.bid
```

These directions follow the TAIFEX futures time-spread definition: near expiry
is encoded first; exchange Buy expands to `BS1=Sell`, `BS2=Buy`, and exchange
Sell expands to `BS1=Buy`, `BS2=Sell`.

### Option combo orders

Managed option combo market-data encoding is not implemented yet; subscribe to
the individual option legs. Do not describe this implementation boundary as a
TAIFEX prohibition: the TMP specification defines native option combo product
codes. Apply these canonical rules when placing a managed option combo:

| Type | Legal shape | Canonical `legs[0]`, `legs[1]` | `Buy` leg actions | `Sell` leg actions | Exchange price |
|---|---|---|---|---|---|
| `PriceSpread` Call | same family/expiry/right, different strikes | higher-strike Call, lower-strike Call | Sell, Buy | Buy, Sell | lower premium - higher premium |
| `PriceSpread` Put | same family/expiry/right, different strikes | lower-strike Put, higher-strike Put | Sell, Buy | Buy, Sell | higher premium - lower premium |
| `TimeSpread` | same family/strike/right, different monthly expiries | near, far | Sell, Buy | Buy, Sell | far premium - near premium |
| `WeeklyTimeSpread` | same shape as time spread; at least one weekly expiry | near, far | Sell, Buy | Buy, Sell | far premium - near premium |
| `Straddle` | same family/expiry/strike, Call + Put | Call, Put | Buy, Buy | Sell, Sell | Call premium + Put premium |
| `Strangle` | same family/expiry, different strikes, Call + Put | Call, Put | Buy, Buy | Sell, Sell | Call premium + Put premium |
| `ConversionReversal` | same family/expiry/strike, Call + Put | Call, Put | Sell Call, Buy Put (Conversion) | Buy Call, Sell Put (Reversal) | Put premium - Call premium |

Weekly/monthly compatibility comes from matching underlying-family metadata,
strike, right, and actual delivery dates. Do not assume arbitrary roots sharing
two characters can combine.

## Net Price 價差淨價

`ComboOrder.price` is the exchange-defined price for the whole combo, not a
per-leg price. Calculate it from the canonical shape, independently of whether
the overall order action is Buy or Sell:

- futures and option time spread: `far - near`;
- Call price spread: `lower-strike Call - higher-strike Call`;
- Put price spread: `higher-strike Put - lower-strike Put`;
- straddle/strangle: `Call + Put`;
- conversion/reversal: `Put - Call`.

For a difference `A - B`, estimate its synthetic market as:

```text
synthetic combo_bid = A.bid - B.ask
synthetic combo_ask = A.ask - B.bid
```

For a sum `A + B`, use `A.bid + B.bid` and `A.ask + B.ask`. The overall
Buy/Sell chooses which side of this canonical combo is traded; it does not
change the exchange price definition.

Use the synthetic bid/ask only as a pre-trade safety estimate. TAIFEX may
match against native combo liquidity and current market state, so refresh
quotes immediately before sending production orders.

| Combo shape | Managed canonical legs | Exchange-price formula | Usually "far from fill" for a buy test |
|---|---|---|---|
| Call price spread | higher-strike Call, lower-strike Call | lower Call - higher Call | Limit far below synthetic `combo_ask` |
| Put price spread | lower-strike Put, higher-strike Put | higher Put - lower Put | Limit far below synthetic `combo_ask` |
| Time spread | near, far | far - near | Limit far below synthetic `combo_ask` |
| Straddle | Call, Put at same strike | Call + Put | Limit far below `Call.ask + Put.ask` |
| Strangle | Call, Put at different strikes | Call + Put | Limit far below `Call.ask + Put.ask` |
| Conversion/reversal | Call, Put at same strike | Put - Call | Limit far below synthetic `combo_ask` |

## Combo Types 組合類型

`combo_type` selects the TAIFEX combo strategy. Shioaji can auto-derive it
from full legs for most standard shapes.

| `sj.ComboType.*` | f_mttype | Strategy |
|---|:---:|---|
| `PriceSpread` | `1` | 價格價差 |
| `TimeSpread` | `2` | 時間價差 / 跨月價差 |
| `Straddle` | `3` | 跨式 |
| `Strangle` | `4` | 勒式 |
| `ConversionReversal` | `5` | 轉換 / 逆轉組合 |
| `WeeklyTimeSpread` | `2` | 週選跨月價差 |

Rules:

- Managed contracts derive `combo_type` only after resolving full current
  Contract V2 Info. A caller-supplied type must match the derived candidate
  set; for the ambiguous Call+Put shape (Straddle vs ConversionReversal) it
  is required and selects the product.
- Reject managed legs that cannot be resolved; never use an explicit type to
  bypass missing family/expiry/strike/right validation.
- Derive `WeeklyTimeSpread` when at least one otherwise-valid time-spread leg
  is weekly. It shares exchange `f_mttype=2` with `TimeSpread` but remains a
  distinct public enum for validation and diagnostics.
- Keep directed `ComboBase` behavior compatible. Explicit `combo_type` and
  per-leg actions continue through the established order path.

## TAIFEX Order Conditions 委託條件

TAIFEX rules differ by product, session, and combo kind:

- **Standard option combo orders** (`PriceSpread`, `Straddle`, `Strangle`,
  `ConversionReversal`, option `TimeSpread`): `ROD` is not available.
  During continuous trading use `LMT + IOC` or `LMT + FOK`.
- **Standard futures time-spread combo orders** can support `ROD` during
  continuous trading, subject to product/session rules.
- **Pre-open** does not accept combo orders, time-spread orders, `FOK`, or
  range-market orders. Do not test combo orders in the pre-open window.
- **Custom contracts** follow a separate table. Regular custom futures
  accept limit orders with `FOK` / `IOC` / `ROD` during continuous trading,
  but that is not the same as standard option combos.

Observed standard option combo behavior:

```text
LMT + ROD -> rejected: 9927 委託條件錯誤 (ORDER-CONDITION)
LMT + IOC -> accepted; if not marketable, exchange cancels immediately
```

## Place Combo Order 下組合單

Futures time-spread example, where `ROD` can be valid for eligible products:

```python
order = sj.ComboOrder(
    action=sj.Action.Buy,  # required for a managed ComboContract
    price=50,  # Net price 淨價
    quantity=1,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_comboorder(combo_contract, order)
```

Standard option combo non-fill validation pattern:

```python
order = sj.ComboOrder(
    action=sj.Action.Buy,  # required for a managed ComboContract
    price=0.1,
    quantity=1,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.IOC,
    combo_type=sj.ComboType.PriceSpread,
    octype=sj.FuturesOCType.Auto,
    account=api.futopt_account,
)

trade = api.place_comboorder(combo_contract, order)
```

Live validation example for a standard TX1 option combo:

```text
Buy  TX148200G6 Call: bid/ask 1.1 / 3.1
Sell TX148250G6 Call: bid/ask 0.9 / 2.0

synthetic combo_ask = 3.1 - 0.9 = 2.2
test buy limit       = 0.1
distance below ask   = 2.1
order_type           = IOC
result               = accepted, no deal, exchange-cancelled
```

## Production Safety 實單安全檢查

Before sending a production combo order:

1. Build exactly two homogeneous legs. For managed legs, confirm the derived
   type, canonical order, and actions expanded from `ComboOrder.action`; for
   legacy legs, confirm each explicit `ComboBase.action`.
2. Refresh both legs' bid/ask and compute synthetic combo bid/ask.
3. For a non-fill buy test, choose a limit far below synthetic `combo_ask`;
   for a non-fill sell test, choose a limit far above synthetic `combo_bid`.
4. Re-sample quotes several times. Abort if either leg loses bid/ask,
   volume goes to zero, or the synthetic combo price moves materially.
5. Confirm the `order_type` is legal for the product/session. For standard
   option combos, use `IOC` or `FOK`, not `ROD`.
6. After placing, confirm final state with order callbacks or
   `update_combostatus(account)` / `list_combotrades()`.

## Status, Cancel, Reconciliation 狀態、取消、對帳

```python
api.cancel_comboorder(trade)
api.update_combostatus(api.futopt_account)
combo_trades = api.list_combotrades()
```

For an `IOC` option combo that is accepted but does not fill, a normal final
state is:

```text
status = Cancelled
status_code = 0000
deal_quantity = 0
cancel_quantity = 1
deals = {}
```

Sync Python note: `update_combostatus` always returns the refreshed
`List[ComboTrade]`. The `cb` argument fires only when `timeout=0`
(non-blocking mode); with the default timeout the callback is never invoked.

## HTTP API

Public shioaji HTTP request bodies use `combo_contract`. Do not send the
backend-internal `combocontract` key to the public HTTP server. JSON legs with
`action` are legacy directed legs; actionless ordinary-contract legs are the
managed form. Reject a request that mixes the two shapes.

```bash
# Managed form (recommended). The server validates the exchange strategy and
# derives per-leg actions from order.action. Buy time spread = sell near, buy far.
curl -X POST http://localhost:8080/api/v1/order/place_comboorder \
  -H "Content-Type: application/json" \
  -d '{
    "combo_contract": {
      "legs": [
        {"security_type": "FUT", "region": "TW", "exchange": "TAIFEX", "code": "TXFH6", "target_code": null},
        {"security_type": "FUT", "region": "TW", "exchange": "TAIFEX", "code": "TXFI6", "target_code": null}
      ],
      "combo_type": "TimeSpread"
    },
    "order": {
      "action": "Buy",
      "price": 10,
      "quantity": 1,
      "price_type": "LMT",
      "order_type": "ROD",
      "octype": "Auto"
    }
  }'

# Legacy directed form; retained for compatibility.
curl -X POST http://localhost:8080/api/v1/order/place_comboorder \
  -H "Content-Type: application/json" \
  -d '{
    "combo_contract": {
      "legs": [
        {"action": "Buy",  "security_type": "FUT", "exchange": "TAIFEX", "code": "TXFG5", "symbol": "TXFG5", "category": "TXF", "delivery_month": "202607"},
        {"action": "Sell", "security_type": "FUT", "exchange": "TAIFEX", "code": "TXFH5", "symbol": "TXFH5", "category": "TXF", "delivery_month": "202608"}
      ]
    },
    "order": {
      "action": "Sell",
      "price": 50,
      "quantity": 1,
      "price_type": "LMT",
      "order_type": "ROD",
      "octype": "Auto",
      "combo_type": "TimeSpread"
    }
  }'
```

In that legacy HTTP example, the two `legs[].action` values determine the leg
directions. The order-level `"action": "Sell"` is accepted for compatibility
but does not rewrite or reinterpret them.

Endpoints:

- `POST /api/v1/order/place_comboorder`: place a combo order.
- `POST /api/v1/order/cancel_comboorder`: cancel by combo trade id.
- `POST /api/v1/order/combotrades`: run `update_combostatus` for the resolved
  futures account and return the result (a live refresh, not a cache read).

## Implementation and QA Invariants

Keep these invariants identical across Python, HTTP, quote, historical-data,
and order paths:

1. Accept exactly two homogeneous legs; reject mixed managed/directed legs.
2. Preserve directed `ComboBase` serialization and behavior byte-for-byte
   unless a separately approved compatibility change is made. Assert that
   changing or omitting `ComboOrder.action` leaves directed leg actions
   unchanged.
3. Resolve managed legs to Info, then run one shared structural
   family/shape/order validator. Apply operation-specific expiry/session checks
   afterward so historical ticks are not incorrectly blocked.
4. Use the same canonical encoder for `subscribe`, `ticks`, `snapshots`, and
   managed order placement.
5. Expand managed leg actions only at order placement. Quote subscription and
   market-data identity never depend on action.
6. Generate `combo_futures` results with the shared validator and return only
   managed contracts.
7. Test every strategy in both overall Buy and Sell directions. Assert the
   exact SW leg order/actions, invalid reversed order, invalid mixed legs,
   mismatching explicit `combo_type`, weekly/monthly family boundaries, and
   unchanged legacy payload fixtures.
8. Preserve whether `ComboOrder.action` was explicitly supplied. Managed mode
   must reject an omitted action even if the legacy model historically exposed
   `Sell` as a default; directed mode must continue to accept omission. Do not
   infer explicit presence from the resolved/default enum value.

## TAIFEX Authority

Use the current official sources when rules or encodings change:

- [TAIFEX order types and combo definitions](https://www.taifex.com.tw/cht/4/oamIntroduction)
- [TAIFEX TCP/IP TMP specification](https://www.taifex.com.tw/cht/8/techDocsDetails?idx=4), v2.18.8 dated 2026-07-06, especially sections 3.5.2–3.5.4 for option combo examples, futures time-spread encoding, BS1/BS2, and product/compound-product relationships.
