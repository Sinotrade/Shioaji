# Combo Orders 組合單

This document covers Shioaji combo orders: legs, net-price calculation,
legal TAIFEX order conditions, Python/HTTP payload fields, and status
confirmation. Combo orders are production-only; simulation/paper mode does
not support placing or cancelling combo orders.

## Mental Model 心智模型

A combo order has three layers:

```text
ComboContract
  legs[0]: ComboBase(action=Buy/Sell, contract fields...)
  legs[1]: ComboBase(action=Buy/Sell, contract fields...)

ComboOrder
  price / quantity / price_type / order_type / octype / account / combo_type

ComboTrade
  contract + order + status
```

Exactly two legs are required. The client raises `ShioajiValueError` when
the leg count is not two, matching the sw backend requirement.

Each `ComboBase.action` is the exchange-facing direction of that leg. The
order-level `ComboOrder.action` defaults to `Sell` for canonical shioaji
compatibility, but the per-leg actions are the direction fields mapped to
STS `ord_bs` and `c_buysell`.

## Required Fields 必填欄位

Fill these fields before sending a combo order:

- `ComboContract.legs`: exactly two `ComboBase` legs.
- `ComboBase.action`: `Buy` or `Sell` for each leg.
- `ComboBase` contract fields: `security_type`, `exchange`, `code`, and
  ideally `symbol`, `category`, `delivery_month`, `strike_price`,
  `option_right`, `target_code` when available.
- `ComboOrder.price`: net combo limit price, not a per-leg price.
- `ComboOrder.quantity`: combo quantity; both legs use this quantity.
- `ComboOrder.price_type`: normally `FuturesPriceType.LMT` for combo orders.
- `ComboOrder.order_type`: must be legal for the product and session.
- `ComboOrder.octype`: usually `FuturesOCType.Auto` unless explicit
  open/close handling is required.
- `ComboOrder.account`: futures/options account. Python calls can omit it
  when `api.futopt_account` is available.
- `ComboOrder.combo_type`: optional when full contract fields allow
  auto-derivation; required for bare-code legs or `WeeklyTimeSpread`.

## Build Combo Contract 建立組合合約

Use `ComboBase.from_contract()` when you have rich contract objects:

```python
r1 = api.contracts.get("TXFR1")
r2 = api.contracts.get("TXFR2")
if r1 is None or r2 is None:
    raise LookupError("continuous futures contract not found")

combo_contract = sj.ComboContract(legs=[
    sj.ComboBase.from_contract(r1, action=sj.Action.Buy),
    sj.ComboBase.from_contract(r2, action=sj.Action.Sell),
])
```

Or fill each leg explicitly:

```python
combo_contract = sj.ComboContract(
    legs=[
        sj.ComboBase(
            action=sj.Action.Buy,
            security_type=sj.SecurityType.Future,
            exchange=sj.Exchange.TAIFEX,
            code="TXFG5",
            symbol="TXFG5",
            category="TXF",
            delivery_month="202607",
        ),
        sj.ComboBase(
            action=sj.Action.Sell,
            security_type=sj.SecurityType.Future,
            exchange=sj.Exchange.TAIFEX,
            code="TXFH5",
            symbol="TXFH5",
            category="TXF",
            delivery_month="202608",
        ),
    ]
)
```

`from_contract` copies `security_type/exchange/code/symbol/category/
delivery_month/strike_price/option_right/target_code`. For bare
`BaseContract` instances, use the field-by-field constructor and pass
`combo_type` explicitly.

## Net Price 價差淨價

`ComboOrder.price` is the net price for the whole combo:

```text
combo net price = sum(+leg_price for Buy legs) - sum(leg_price for Sell legs)
```

For a two-leg buy-debit spread:

```text
Leg 1: Buy  A
Leg 2: Sell B

net price = A - B
synthetic combo_bid = A.bid - B.ask
synthetic combo_ask = A.ask - B.bid
```

Use the synthetic bid/ask only as a pre-trade safety estimate. TAIFEX may
match against native combo liquidity and current market state, so refresh
quotes immediately before sending production orders.

| Combo shape | Legs | Net-price formula | Usually "far from fill" for a buy test |
|---|---|---|---|
| Call debit price spread | Buy lower-strike Call, Sell higher-strike Call | lower Call - higher Call | Limit far below synthetic `combo_ask` |
| Put debit price spread | Buy higher-strike Put, Sell lower-strike Put | higher Put - lower Put | Limit far below synthetic `combo_ask` |
| Time spread | Buy one month, Sell another month | bought month - sold month | Limit far below synthetic `combo_ask` for a buy; far above synthetic `combo_bid` for a sell |
| Long straddle | Buy Call, Buy Put, same strike/month | Call + Put | Limit far below `Call.ask + Put.ask` |
| Long strangle | Buy OTM Call, Buy OTM Put, same month | Call + Put | Limit far below `Call.ask + Put.ask` |

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

- Full futures/options contracts usually let Shioaji auto-fill
  `combo_type`.
- Bare `BaseContract` legs cannot be inferred reliably; pass
  `combo_type=sj.ComboType.<variant>`.
- `WeeklyTimeSpread` must be explicit because it shares `f_mttype=2` with
  `TimeSpread`.
- An explicit `combo_type` overrides auto-derivation.

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

1. Build exactly two `ComboBase` legs and confirm each leg's `action`.
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

Sync Python note: `update_combostatus(account, cb=...)` returns `None` when
a callback is supplied. Read the callback payload or call
`list_combotrades()` afterward. Without a callback, use
`list_combotrades()` after `update_combostatus(account)` to inspect cached
combo trades.

## HTTP API

Public shioaji HTTP request bodies use `combo_contract`. Do not send the
backend-internal `combocontract` key to the public HTTP server.

```bash
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

Endpoints:

- `POST /api/v1/order/place_comboorder`: place a combo order.
- `POST /api/v1/order/cancel_comboorder`: cancel by combo trade id.
- `POST /api/v1/order/combotrades`: list cached combo trades.
