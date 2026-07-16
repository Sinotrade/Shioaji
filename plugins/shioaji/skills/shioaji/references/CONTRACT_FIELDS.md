# Contract V2 Info Fields 商品資訊欄位

Full field reference for the typed Info objects returned by `api.contracts.info(base)`
(and by the legacy `api.Contracts.*` facade). Field types are shown as they appear
in the Python SDK; `repr()` omits fields whose value is `None`.

`api.contracts.info(base)` 回傳的型別化 Info 物件（以及舊版 `api.Contracts.*` facade）
完整欄位參考。型別以 Python SDK 呈現為準；`repr()` 中值為 `None` 的欄位會被省略。

### Contract (Base) Attributes 商品識別屬性

The Base contract returned by `get()` / `list()`. Info objects expose these plus
their typed fields. Orders and subscriptions accept the Base directly.
`get()` / `list()` 回傳的識別型商品；Info 物件在此之上再加型別化欄位。下單與訂閱可直接使用 Base。

```python
security_type   # str: security type {STK, IND, FUT, OPT, WRT} 商品類型
region          # str: market region 市場區域
exchange        # str: exchange 交易所
code            # str: product code 商品代碼
target_code     # str: resolved target code; continuous-month futures (e.g. TXFR1/R2) only 實際目標代碼，僅期貨連續月（如 TXFR1/R2）才有值
```

### StockInfo Attributes 證券資訊屬性

```python
code                              # str: product code 商品代碼
name                              # str: product name 商品名稱
category                          # str: industry category 產業別
currency                          # Currency: trading currency 交易幣別
unit                              # float: trading unit 交易單位
day_trade                         # DayTrade: day trade eligibility {Yes, OnlyBuy, No} 當沖資格
reference                         # float: reference price 參考價
limit_up                          # float: limit-up price 漲停價
limit_down                        # float: limit-down price 跌停價
margin_trading_balance            # int: margin trading balance 融資餘額
short_selling_balance             # int: short selling balance 融券餘額
trading_suspended                 # bool: trading suspended 暫停交易
margin_loan_ratio                 # float: margin loan ratio 融資成數
margin_quota_lots                 # int: margin quota (lots) 融資配額張數
short_margin_ratio                # float: short selling margin ratio 融券保證金成數
short_quota_lots                  # int: short selling quota (lots) 融券配額張數
short_selling_suspended           # bool: short selling suspended 暫停融券
disposition_level                 # int: disposition level (0 when not under disposition) 處置等級（無處置為 0）
attention_flag                    # bool: attention stock 注意股票
short_below_par_eligible          # bool: short selling below par eligible 可低於面額融券
slb_below_par_eligible            # bool: securities lending below par eligible 可低於面額借券
etf_constituent                   # bool: ETF constituent ETF 成分股
settlement_type                   # str: settlement type 交割類型
disposition_match_interval_min    # int: disposition matching interval (minutes) 處置撮合間隔（分鐘）
disposition_max_lots_single_order # int: disposition max lots per order 處置單筆上限（張）
disposition_max_lots_total_orders # int: disposition max lots across orders 處置累計上限（張）
disposition_prepay_ratio          # float: disposition prepayment ratio 處置預收比例
update_date                       # date: data date 資料日期
```

### FuturesInfo Attributes 期貨資訊屬性

```python
code             # str: product code 商品代碼
name             # str: product name 商品名稱
root             # str: product root 商品根代碼
delivery_month   # str: delivery month 契約月份
delivery_date    # date: expiry / settlement date 到期／交割日期
last_trading_date # date: last trading date 最後交易日
begin_date       # date: first trading date 開始交易日
underlying_kind  # str: underlying kind {S stock, I index, E FX, C commodity} 標的種類 {S 股票, I 指數, E 外匯, C 商品}
underlying_code  # str: underlying code 標的代碼
multiplier       # float: contract multiplier 契約乘數
contract_size    # float: contract size 契約規模
size_unit        # str: contract size unit 契約規模單位
quote_ccy        # str: quote currency 報價幣別
tick_basis       # str: tick basis {fixed, price, premium} 跳動規則基礎 {fixed 固定, price 依價格, premium 依權利金}
tick_rule        # str: tick rule code 跳動規則代碼
tick             # float: minimum tick 最小跳動點
tick_value       # float: value per tick 每跳價值
spec_kind        # str: contract spec kind 契約規格類型
decimal_locator  # int: price decimal places 價格小數位設定
dynamic_banding  # bool: dynamic price banding 動態價格穩定措施
flow_group       # str: flow control group 流量管制組別
reference        # float: reference price 參考價
limit_up         # float: tier-1 upper limit 第一階段漲幅上限
limit_down       # float: tier-1 lower limit 第一階段跌幅下限
limit_up_2       # float: tier-2 upper limit 第二階段漲幅上限
limit_down_2     # float: tier-2 lower limit 第二階段跌幅下限
limit_up_3       # float: tier-3 upper limit 第三階段漲幅上限
limit_down_3     # float: tier-3 lower limit 第三階段跌幅下限
update_date      # date: data date 資料日期
```

`spec_kind` values 契約規格類型:
- `index_fut` — index futures 指數期貨
- `stock_fut` — single-stock futures 個股期貨
- `etf_fut` — ETF futures ETF 期貨
- `commodity` — commodity futures 商品期貨
- `fx` — FX futures 外匯期貨
- `unknown` — spec mapping not yet complete 尚未完成規格對照

### OptionInfo Attributes 選擇權資訊屬性

```python
code                   # str: product code 商品代碼
name                   # str: product name 商品名稱
root                   # str: product root 商品根代碼
delivery_month         # str: delivery month 契約月份
delivery_date          # date: expiry / settlement date 到期／交割日期
last_trading_date      # date: last trading date 最後交易日
begin_date             # date: first trading date 開始交易日
strike_price           # float: strike price 履約價
option_right           # OptionRight: call or put {Call, Put} 買賣權 {Call, Put}
expiry_weekday         # str: expiry weekday 到期星期
week_of_month          # int: week of month within the delivery month 月內到期週次
underlying_kind        # str: underlying kind {S stock, I index, E FX, C commodity} 標的種類 {S 股票, I 指數, E 外匯, C 商品}
underlying_code        # str: underlying code 標的代碼
multiplier             # float: contract multiplier 契約乘數
contract_size          # float: contract size 契約規模
size_unit              # str: contract size unit 契約規模單位
quote_ccy              # str: quote currency 報價幣別
tick_basis             # str: tick basis {fixed, price, premium} 跳動規則基礎 {fixed 固定, price 依價格, premium 依權利金}
tick_rule              # str: tick rule code 跳動規則代碼
tick                   # float: minimum tick 最小跳動點
tick_value             # float: value per tick 每跳價值
spec_kind              # str: contract spec kind 契約規格類型
decimal_locator        # int: price decimal places 價格小數位設定
strike_decimal_locator # int: strike price decimal places 履約價小數位
dynamic_banding        # bool: dynamic price banding 動態價格穩定措施
flow_group             # str: flow control group 流量管制組別
reference              # float: reference price 參考價
limit_up               # float: tier-1 upper limit 第一階段漲幅上限
limit_down             # float: tier-1 lower limit 第一階段跌幅下限
limit_up_2             # float: tier-2 upper limit 第二階段漲幅上限
limit_down_2           # float: tier-2 lower limit 第二階段跌幅下限
limit_up_3             # float: tier-3 upper limit 第三階段漲幅上限
limit_down_3           # float: tier-3 lower limit 第三階段跌幅下限
update_date            # date: data date 資料日期
```

`spec_kind` values 契約規格類型:
- `index_opt` — index options 指數選擇權
- `stock_opt` — single-stock options 個股選擇權
- `etf_opt` — ETF options ETF 選擇權
- `commodity_opt` — commodity options 商品選擇權
- `unknown` — spec mapping not yet complete 尚未完成規格對照

### IndexInfo Attributes 指數資訊屬性

```python
code         # str: product code 商品代碼
name         # str: index name 指數名稱
reference    # float: reference index value 參考指數值
open_time    # str: quote start time 行情開始時間
close_time   # str: quote end time 行情結束時間
update_date  # date: data date 資料日期
```

### WarrantInfo Attributes 權證資訊屬性

Warrants do not support `api.contracts.info()`; query them via `warrants(underlying)`.
權證不支援 `api.contracts.info()`，請透過 `warrants(標的)` 以標的查詢。

```python
code                # str: product code 商品代碼
name                # str: warrant name 權證名稱
underlying_code     # str: underlying code 標的商品代碼
underlying_type     # str: underlying type 標的商品類別
call_put            # str: call / put {C call, P put} 認購／認售 {C 認購, P 認售}
financial           # str: security type code 證券別代碼
strike_price        # float: strike price 履約價
expiry_date         # date: expiry date 到期日
last_trading_date   # date: last trading date 最後交易日
exercise_ratio      # float: exercise ratio 行使比例
exercise_style      # str: exercise style {American, European} 行使型態 {American 美式, European 歐式}
listing_date        # date: listing date 上市日
delisting_date      # date: delisting date 下市日
exercise_start_date # date: exercise start date 行使開始日
exercise_end_date   # date: exercise end date 行使截止日
barrier_upper       # float: upper barrier price 上限障礙價
barrier_lower       # float: lower barrier price 下限障礙價
residual_value      # float: residual / compensation value 剩餘價值／補償價
settlement_method   # str: settlement method 履約結算方式
investor_restriction # str: investor restriction type 投資人限制類別
issue_size          # int: issue size 發行數量
reference           # float: reference price 參考價
limit_up            # float: limit-up price 漲停價
limit_down          # float: limit-down price 跌停價
update_date         # date: data date 資料日期
```
