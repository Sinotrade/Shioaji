# Migration and Deprecated Patterns

This skill uses Shioaji 1.5 as the baseline. Use this reference only when a user asks about migration, generated code contains older Shioaji idioms, or bundled references need deprecated-code comparison.

Reference scope:

- Use this file for Shioaji 1.5 baseline rules and deprecated-code comparison.
- Do not generate migration-only patterns as recommended code.
- For installed CLI or HTTP details that must be exact, confirm with the local CLI `--help` output or the running server's `/openapi.json`.

## Baseline rules

| Area | Baseline in this skill | Migration-only / do not generate |
|------|------------|-----------------|
| Imports | `from shioaji import Action, StockOrderCond, Trade, OrderState` | `from shioaji.constant import ...`, `from shioaji.order import ...`, `from shioaji.position import ...` |
| Object export | `obj.dict()` | `obj.__dict__` |
| Subscribe quotes | `api.subscribe(contract, quote_type=...)` | `api.quote.subscribe(...)` |
| Unsubscribe quotes | `api.unsubscribe(contract, quote_type=...)` | `api.quote.unsubscribe(...)` |
| Stock order | `sj.StockOrder(...)` | `api.Order(...)` |
| Futures/options order | `sj.FuturesOrder(...)` | `api.Order(...)` |
| CLI install | `uv tool install shioaji` | old package names |
| HTTP server setup | `.env` + `shioaji server start` | credentials hard-coded in command examples |

## Canonical baseline snippets

### Top-level imports

```python
from shioaji import (
    Action,
    FuturesOCType,
    OrderState,
    OrderType,
    StockOrderCond,
    StockOrderLot,
    StockPriceType,
    Trade,
)
```

### Stock order

```python
import shioaji as sj

contract = api.Contracts.Stocks["2330"]
order = sj.StockOrder(
    action=sj.Action.Buy,
    price=580,
    quantity=1,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_lot=sj.StockOrderLot.Common,
    order_cond=sj.StockOrderCond.Cash,
)
trade = api.place_order(contract, order)
```

`trade` is a `Trade`. Check `trade.status.status` before deciding whether to call `api.update_status(...)`; see [ORDERS.md](ORDERS.md).

### Futures/options order

```python
import shioaji as sj

contract = api.Contracts.Futures["TXFC0"]
order = sj.FuturesOrder(
    action=sj.Action.Buy,
    price=18000,
    quantity=1,
    price_type=sj.FuturesPriceType.LMT,
    order_type=sj.OrderType.ROD,
    octype=sj.FuturesOCType.Auto,
)
trade = api.place_order(contract, order)
```

### Subscribe / unsubscribe

```python
api.subscribe(api.Contracts.Stocks["2330"], quote_type=sj.QuoteType.Tick)
api.unsubscribe(api.Contracts.Stocks["2330"], quote_type=sj.QuoteType.Tick)
```

### CLI and HTTP server setup

Create `.env` where `shioaji server start` will run:

```dotenv
SJ_API_KEY=YOUR_API_KEY
SJ_SEC_KEY=YOUR_SECRET_KEY
SJ_CA_PATH=your/ca/path/Sinopac.pfx
SJ_CA_PASSWD=YOUR_CA_PASSWORD
SJ_PRODUCTION=false
```

Then:

```bash
uv tool install shioaji
shioaji server start
```

## Deprecated / migration comparison

These examples are shown only to recognize and migrate old code. Do not use them as new recommendations.
These patterns are allowed only in this migration/deprecated comparison reference. If they appear in other skill references, treat them as stale content that should be corrected.

```python
from shioaji.constant import Action
from shioaji.order import Trade
from shioaji.position import AccountBalance

df = pd.DataFrame(s.__dict__ for s in positions)

api.quote.subscribe(api.Contracts.Stocks["2330"], quote_type=...)
api.quote.unsubscribe(api.Contracts.Stocks["2330"])

order = api.Order(action="Buy", price=30, quantity=1, price_type="LMT")
```

## Decision rules for agents

- If a user provides old code, rewrite only the affected API calls and preserve their trading intent.
- If the user asks what changed in 1.5, summarize the baseline rules above directly.
- If response handling matters, load the matching functional reference before deciding whether to retry, call `update_status`, subscribe to SSE, or treat an empty result as normal.
