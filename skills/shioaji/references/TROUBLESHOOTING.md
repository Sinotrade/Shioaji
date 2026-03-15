# Troubleshooting 常見問題

Common issues and solutions for Shioaji.
Shioaji 常見問題與解決方案。

---

## Orders 下單相關

### How to place MKT/MKP orders 如何下市價單

Market orders (MKT/MKP) must use IOC or FOK, not ROD.
市價單必須使用 IOC 或 FOK，不能用 ROD。

```python
order = api.Order(
    action=sj.constant.Action.Buy,
    price=0,  # MKT/MKP ignores price 市價單忽略價格
    quantity=1,
    price_type=sj.constant.FuturesPriceType.MKT,  # or MKP
    order_type=sj.constant.OrderType.IOC,  # Must be IOC or FOK 必須是 IOC 或 FOK
    octype=sj.constant.FuturesOCType.Auto,
    account=api.futopt_account
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
@api.quote.on_event
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

## Reference 參考資料

- QA Forum 問答論壇: https://sjapi.tw/
- Official docs 官方文檔: https://sinotrade.github.io/qa/
