# Reserve Orders 預收券款

For stocks under disposition (處置股), attention (注意股), or warning (警示股), you must reserve shares before trading.
處置股、注意股或警示股在交易前須預收券款。

Service hours: 8:00 - 14:30 on trading days.
服務時間：交易日 8:00 至 14:30。

---

## Query Reserve Summary 查詢預收券款狀態

```python
import shioaji as sj

api = sj.Shioaji()
api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")

# Get reserve summary 取得預收券款摘要
reserve_summary = api.stock_reserve_summary(api.stock_account)

for stock in reserve_summary.response.stocks:
    print(f"Code: {stock.contract.code}")
    print(f"Available: {stock.available_share}")
    print(f"Reserved: {stock.reserved_share}")
```

### ReserveStockSummary Attributes 預收摘要屬性

```python
stock.contract         # Contract: Stock contract 股票合約
stock.available_share  # int: Available shares 可預收股數
stock.reserved_share   # int: Already reserved 已預收股數
```

---

## Reserve Stock 預收股票

```python
contract = api.Contracts.Stocks["2890"]

# Reserve 1000 shares 預收 1000 股
resp = api.reserve_stock(api.stock_account, contract, 1000)

print(f"Status: {resp.response.status}")
print(f"Share: {resp.response.share}")
```

### ReserveOrderResp Attributes 預收回應屬性

```python
resp.response.contract  # Stock: Stock contract 股票合約
resp.response.account   # Account: Stock account 股票帳戶
resp.response.share     # int: Reserved shares 預收股數
resp.response.status    # bool: Success status 是否成功
resp.response.info      # str: Info message 資訊訊息
```

---

## Query Reserve Detail 查詢預收明細

```python
detail = api.stock_reserve_detail(api.stock_account)

for stock in detail.response.stocks:
    print(f"Code: {stock.contract.code}")
    print(f"Share: {stock.share}")
    print(f"Status: {stock.status}")
    print(f"Info: {stock.info}")
```

### ReserveStockDetail Attributes 預收明細屬性

```python
stock.contract   # Contract: Stock contract 股票合約
stock.share      # int: Reserved shares 預收股數
stock.order_ts   # int: Order timestamp 委託時間戳
stock.status     # bool: Status 狀態
stock.info       # str: Info (e.g., "已完成") 資訊
```

---

## Reserve Earmarking 預收款項

For pre-payment of cash when buying disposition stocks:
買進處置股時的現金預收款項：

```python
contract = api.Contracts.Stocks["2890"]

# Reserve with price 預收並指定價格
resp = api.reserve_earmarking(api.stock_account, contract, 1000, 15.15)

print(f"Amount: {resp.response.amount}")
print(f"Status: {resp.response.status}")
```

### EarmarkingOrderResp Attributes 預收款項回應屬性

```python
resp.response.contract  # Stock: Stock contract 股票合約
resp.response.account   # Account: Stock account 股票帳戶
resp.response.share     # int: Shares 股數
resp.response.price     # float: Price 價格
resp.response.amount    # int: Total amount 總金額
resp.response.status    # bool: Success status 是否成功
resp.response.info      # str: Info message 資訊訊息
```

---

## Query Earmarking Detail 查詢預收款項明細

```python
detail = api.earmarking_detail(api.stock_account)

for stock in detail.response.stocks:
    print(f"Code: {stock.contract.code}")
    print(f"Share: {stock.share}")
    print(f"Price: {stock.price}")
    print(f"Amount: {stock.amount}")
    print(f"Status: {stock.status}")
```

### EarmarkStockDetail Attributes 預收款項明細屬性

```python
stock.contract   # Contract: Stock contract 股票合約
stock.share      # int: Shares 股數
stock.price      # float: Price 價格
stock.amount     # int: Total amount 總金額
stock.order_ts   # int: Order timestamp 委託時間戳
stock.status     # bool: Status 狀態
stock.info       # str: Info (e.g., "扣款失敗") 資訊
```

---

## Reserve All Available 全部預收

```python
# Reserve all available shares 預收所有可用股票
reserve_summary = api.stock_reserve_summary(api.stock_account)

for stock in reserve_summary.response.stocks:
    if stock.available_share > 0:
        resp = api.reserve_stock(
            api.stock_account,
            stock.contract,
            stock.available_share
        )
        print(f"Reserved {stock.contract.code}: {resp.response.status}")
```

---

## Reference 參考資料

- Official docs 官方文檔: https://sinotrade.github.io/tutor/order/Reserve/
