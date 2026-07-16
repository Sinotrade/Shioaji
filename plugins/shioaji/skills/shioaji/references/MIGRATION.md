# Migration and Deprecated Patterns

Shioaji 1.5 remains the compatibility baseline, while 1.7 Contract V2 intentionally changes contract access. Use this reference only when a user asks about migration, generated code contains older Shioaji idioms, or bundled references need deprecated-code comparison.

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
| Contract lookup (1.7) | `api.contracts.get(...)`, typed `info(...)`, root/underlying queries | `api.Contracts.*`, login-time full contract loading |

## 1.5 → 1.7 breaking changes 破壞性變更

Contracts v2 rewrites contract loading. Most existing code runs unchanged
(`api.Contracts.*` still works; orders, subscriptions, historical data are the
same), but these six changes can break 1.5 code:

1. **`login()` dropped the contract arguments.** `fetch_contract`,
   `contracts_timeout`, and `contracts_cb` were removed — login no longer
   downloads contracts. Remove these kwargs.
   ```python
   # 1.5
   api.login(api_key=..., secret_key=..., contracts_timeout=10000, contracts_cb=cb)
   # 1.7
   api.login(api_key=..., secret_key=...)
   ```

2. **`SecurityType.Future` → `SecurityType.Futures`** (singular → plural).
   `sj.SecurityType.Future` now raises `AttributeError`; use `.Futures`. The
   module-level `from shioaji import Future` still works (unrelated). New member:
   `SecurityType.Warrant`. Wire strings unchanged: `STK`/`FUT`/`OPT`/`IND`/`WRT`.

3. **Queried contract objects renamed.** `Stock`/`Future`/`Option`/`Index` →
   `StockInfo`/`FuturesInfo`/`OptionInfo`/`IndexInfo`, plus new `WarrantInfo`.
   Both `api.Contracts` (legacy) and `api.contracts` (new) now return these Info
   objects. If code references a field that only existed on the old objects
   (e.g. `symbol`), adjust it.

4. **Index codes are now exchange codes.** The TAIEX is `IX0001` (was `001`);
   the pre-1.7.0 code `001` no longer resolves (returns 404 / `None`).

5. **`api.Contracts` → `api.contracts`.** The lowercase query API replaces the
   uppercase facade. The facade still works and now returns the new `*Info`
   objects, emitting a `DeprecationWarning` (hidden by default).

6. **HTTP contract endpoints changed from POST to GET.** Contract queries that
   used `POST` + a JSON body are now `GET` + query parameters, with re-layered
   paths (see [HTTP_API.md](HTTP_API.md)).

Contracts v2 cache lives under a `contracts-v2-{MAJOR}.{MINOR}/` subdirectory;
`SJ_CONTRACTS_PATH` is still honored.

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

contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")
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

contract = api.contracts.get("TXFR1")
if contract is None:
    raise LookupError("contract TXFR1 not found")
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
contract = api.contracts.get("2330")
if contract is None:
    raise LookupError("contract 2330 not found")
api.subscribe(contract, quote_type=sj.QuoteType.Tick)
api.unsubscribe(contract, quote_type=sj.QuoteType.Tick)
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

contract = api.Contracts.Stocks["2330"]
future = api.Contracts.Futures.TXF.TXFR1

order = api.Order(action="Buy", price=30, quantity=1, price_type="LMT")
```

## Decision rules for agents

- If a user provides old code, rewrite only the affected API calls and preserve their trading intent.
- If the user asks what changed in 1.5, summarize the baseline rules above directly.
- If response handling matters, load the matching functional reference before deciding whether to retry, call `update_status`, subscribe to SSE, or treat an empty result as normal.
