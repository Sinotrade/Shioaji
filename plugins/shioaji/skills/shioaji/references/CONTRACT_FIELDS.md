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
region          # str: market region {TW, US} 市場區域
exchange        # str: exchange {TSE, OTC, OES, TAIFEX; US: NASDAQ, NYSE, BATS, TXSE} 交易所
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
margin_shortable                  # bool: margin short selling allowed 可融券賣出
sbl_shortable                     # bool: securities borrowing and lending short selling allowed 可借券賣出
below_ref_shortable               # bool: margin/SBL short selling below reference price allowed 可低於平盤參考價融券／借券賣出
disposition_level                 # int: disposition level (0 when not under disposition) 處置等級（無處置為 0）
attention_flag                    # bool: attention stock 注意股票
etf_constituent                   # bool: ETF constituent ETF 成分股
settlement_type                   # str: settlement type 交割類型
disposition_match_interval_min    # int: disposition matching interval (minutes) 處置撮合間隔（分鐘）
disposition_max_lots_single_order # int: disposition max lots per order 處置單筆上限（張）
disposition_max_lots_total_orders # int: disposition max lots across orders 處置累計上限（張）
disposition_prepay_ratio          # float: disposition prepayment ratio 處置預收比例
update_date                       # date: data date 資料日期
```

The three short-sale eligibility fields are required booleans sourced from the
matching exchange's official daily list: TWSE for `TSE`, TPEx for `OTC`.
`OES` and contracts absent from the matching validated list return `False`.
They describe security-level exchange rules, not account permission, available
inventory, quota, or final order acceptance.

三個券賣資格欄位都是必定有值的布林值，來源是商品所屬交易所的官方每日
名單：`TSE` 使用證交所，`OTC` 使用櫃買中心；`OES` 與不在相符且已驗證
名單內的商品回傳 `False`。它們表示證券層級的交易所規則，不代表特定帳戶
權限、可用券源、額度或最終委託一定接受。

- 融券賣出：`margin_shortable is True`
- 借券賣出：`sbl_shortable is True`
- 低於平盤參考價融券賣出：`margin_shortable and below_ref_shortable`
- 低於平盤參考價借券賣出：`sbl_shortable and below_ref_shortable`

`below_ref_shortable` is only the below-reference price-rule flag; it does not
by itself make either short-selling channel available. The legacy SOR-derived
wire/cache fields `short_selling_suspended`, `short_below_par_eligible`, and
`slb_below_par_eligible` remain for released 1.7 client decoding only. New
Python attributes, `dir()`, `dict()`, stubs, HTTP/OpenAPI, and CLI output do not
expose them.

`below_ref_shortable` 只表示是否通過低於平盤參考價的價格規則，不能單獨解讀成
融券或借券可賣。舊 SOR 欄位只保留在 wire/cache 供已發布的 1.7 client 解碼；
新版 Python、HTTP 與 CLI 公開介面不再揭露。

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

### UsStockInfo Attributes 美股資訊屬性

> **1.8.0b1 pre-release.** US stocks ship in 1.8.0b1 (`pip install --pre
> shioaji` or `shioaji==1.8.0b3`). Ordering and quotes: see
> [CONTRACTS.md § US Stocks](CONTRACTS.md#us-stocks-美股).
> **1.8.0b1 預發行版**起支援美股；下單與行情見 CONTRACTS.md 美股一節。

Returned by `api.contracts.info(base)` when `base.region == "US"` and
`base.security_type == "STK"`. It is a different class from the Taiwan
`StockInfo`: none of the TW rule fields (limits, margin/short, disposition,
day trade) exist for US stocks.
`base.region == "US"` 且 `security_type == "STK"` 時回傳 `UsStockInfo`，與台股
`StockInfo` 是不同類別，沒有漲跌停、融資券、處置、當沖等台股欄位。

```python
code                  # str: ticker exactly as listed, never normalised (AAPL, BRK.A, ABR-D, AAC+) 原樣代碼
exchange              # str: base exchange {NASDAQ, NYSE, BATS, TXSE} 交易所（見下表）
exchange_mic          # ExchangeMic: listing venue MIC (8 values) 上市板 MIC
name                  # str: full English security name 英文完整名稱
short_name            # str: brokerage short name; falls back to name 複委託簡稱
underlying_code       # str: underlying common stock, only for WRT/PR/UNIT/RT 標的普通股代碼（僅 WRT/PR/UNIT/RT）
instrument_type       # InstrumentType: 13 types, see below 商品類型
isin                  # str: ISIN; None until licensing is confirmed ISIN（授權確認前一律 None）
currency              # Currency: always USD 幣別（固定 USD）
round_lot             # int: round-lot size in shares 整股單位（股）
reference             # float: dividend/split-adjusted reference price 除權息調整後參考價
reference_date        # date: US Eastern trading date of the close behind reference 參考價對應的收盤日（美東）
trading_suspended     # bool: suspended at the brokerage 複委託暫停交易
industry_l1           # IndustryL1: FactSet RBICS level 1 (Economy) 產業第一層
industry_l2           # IndustryL2: FactSet RBICS level 2 (Sector) 產業第二層
classification_source # ClassificationSource: direct / parent 分類來源
fund_category         # FundCategory: FactSet ETF fund category (ETF/ETN) 基金類別
fund_sponsor          # str: fund sponsor (ETF/ETN) 基金發行商
expense_ratio         # float: expense ratio in percent (ETF/ETN) 費用率（%）
benchmark_index       # str: tracked index; passive funds only 追蹤指數（僅被動型）
dividend_frequency    # DividendFrequency: payments per year; ETF/ETN only, None for stocks 每年配息次數（僅 ETF/ETN，個股為 None）
update_date           # date: production date of this data (Taipei), same as TW 資料日期（台北，與台股相同）
```

Names are English only; there is no Chinese name for US stocks.
美股只有英文名稱，沒有中文名稱。

**Unknown codes 未知代碼.** Coded fields (`exchange_mic`, `instrument_type`,
`classification_source`, `industry_l1`, `industry_l2`, `fund_category`,
`dividend_frequency`) are enums for codes this SDK knows. A code added by the
server after your SDK version is returned as the raw `str` / `int` instead
of failing. Enums compare equal to their raw code, so
`info.instrument_type == "ETF"` and `info.industry_l1 == 30` work for both.
Each enum has `.value` (raw code), `.name`, `.description` and
`Enum.members()`. HTTP and CLI always emit the raw codes.
編碼欄位在 SDK 認得時為 enum；伺服器新增、舊版 SDK 不認得的代碼會以原始 `str`／`int`
回傳而不會報錯。enum 與原始代碼可直接用 `==` 比較；HTTP 與 CLI 一律輸出原始代碼。

#### Exchanges 交易所

Base `exchange` groups listing venues; `exchange_mic` keeps the exact venue.
Within one exchange a code is unique.
base 的 `exchange` 是交易所集團；`exchange_mic` 是實際上市板。

| `exchange` | Meaning 說明 | `exchange_mic` values |
|------------|--------------|-----------------------|
| `NASDAQ` | Nasdaq, all three tiers | `XNGS` Global Select, `XNMS` Global Market, `XNCM` Capital Market |
| `NYSE` | NYSE group: NYSE, NYSE Arca, NYSE American | `XNYS` NYSE, `ARCX` NYSE Arca, `XASE` NYSE American (formerly AMEX) |
| `BATS` | Cboe BZX Exchange | `BATS` |
| `TXSE` | Texas Stock Exchange (first listing: ETF `PWRX`) | `TXSE` |

`ExchangeMic.<MIC>.exchange` returns the base `Exchange`.

#### instrument_type 商品類型

All 13 types trade as `security_type="STK"`.
13 類都屬於 `security_type="STK"`。

| Code | Meaning 說明 | Example |
|------|--------------|---------|
| `CS` | Common stock 普通股 | `AAPL` |
| `PR` | Preferred stock 優先股 | `ABR-D` |
| `ADR` | American depositary receipt 存託憑證 | `TSM` |
| `REIT` | Real estate investment trust 不動產投資信託 | `O` |
| `LP` | Limited partnership (e.g. MLP units) 有限合夥 | `EPD` |
| `TRUST` | Trust units (royalty / grantor trusts) 信託 | `PBT` |
| `ETF` | Exchange-traded fund 指數股票型基金 | `SPY` |
| `ETN` | Exchange-traded note 指數投資證券 | `VXX` |
| `CEF` | Closed-end fund 封閉型基金 | `ADX` |
| `NOTE` | Exchange-listed note / baby bond 掛牌債券 | `JBK`; many `… % Notes due …` issues such as `AIZN` |
| `WRT` | Warrant 認股權證 | `AACIW`, `AAC+` |
| `UNIT` | Unit — usually a SPAC unit (one share plus warrants or rights that later separate) SPAC 單位 | `ACGCU`, `APMCU` |
| `RT` | Right — usually a SPAC right to receive a fraction of a share at the merger SPAC 權利 | `DMAAR` |

`WRT` here is a US warrant listed as a stock (`security_type="STK"`,
`instrument_type="WRT"`). It is **not** the Taiwan `security_type="WRT"`
covered warrant and has no `api.contracts.warrants()` shard.
美股權證放在 STK 底下，與台股 `security_type="WRT"` 的權證不同。

`underlying_code` is filled only for `WRT`, `PR`, `UNIT` and `RT` and holds
the underlying common stock (e.g. `AACIW` → `AACI`, `ABR-D` → `ABR`);
it is `None` for every other type.
`underlying_code` 只有 WRT／PR／UNIT／RT 會填標的普通股代碼。

#### Trading rules (market-wide, not stored per contract) 全市場交易規則

- Orders are in whole shares; the order unit is 1 share. 下單以 1 股為單位。
- `round_lot` is the SEC round-lot size (100 for most stocks, smaller for
  high-priced ones). Only orders of at least one round lot count toward the
  displayed best bid/offer; odd-lot orders still trade. `round_lot` 為整股
  單位，只有整股掛單會列入揭示的最佳買賣價。
- Prices have up to 4 decimal places. 價格最多 4 位小數。
- Tick size: `0.01` at or above USD 1.00, `0.0001` below USD 1.00
  (Reg NMS Rule 612). 跳動單位：1 美元以上 0.01、未滿 1 美元 0.0001。
- There are no daily price limits (no `limit_up` / `limit_down`). 無漲跌停。
- Currency is always `USD`. 幣別固定 USD。

#### reference / reference_date 參考價

`reference` is the reference price for the next US session: the previous
session's official close **adjusted for corporate actions that go ex on the
next session** (cash dividends and splits). It comes from the market-data
vendor's reference price (CFAPI token 7094), e.g. close 12.79 with a 0.33
dividend going ex → `reference` 12.46; with no event it equals the close.
`reference_date` (CFAPI token 7095) is the **US Eastern** trading date of
that close (the previous US session), not a Taiwan date. When the vendor has
no adjusted price the field is `None` rather than an unadjusted fallback.
`reference` 為下一個美股交易日的參考價：前一交易日官方收盤價，並已扣除下一交易日
除權息（現金股利、分割）的影響（來源 CFAPI 7094）；`reference_date`（CFAPI 7095）
為該收盤價的美東交易日。來源沒有調整後價格時為 `None`。

> Test environments using the vendor trial account replay market data about
> 21 days back, so `reference_date` there lags the calendar by ~3 weeks.
> 使用試用帳號的測試環境，行情約重播 21 天前的資料，`reference_date` 會落後約三週。

#### trading_suspended 暫停交易

Updated once per trading day at about 17:30 Taipei with the producer batch,
which queries the brokerage back office (TSHK5090). It reflects brokerage
suspension status before the next US session. Intraday exchange halts are
not reflected here — use market data for those.
每個交易日約台北 17:30 隨商品檔批次更新（查詢複委託後台 TSHK5090），表示下一個美股
交易時段前的停牌狀態；盤中交易所暫停不會反映在此欄位，請以行情判斷。

#### update_date 資料日期

Production date of the info data in Taipei time (`YYYY-MM-DD`), the same
meaning as TW `update_date`. It is a Taipei date, while `reference_date` is
a US Eastern date.
商品資訊的產出日期（台北），與台股相同；`reference_date` 則是美東日期。

#### industry_l1 / industry_l2 產業分類 (FactSet RBICS)

`industry_l1` is RBICS level 1 (RBICS calls it **Economy**, 14 codes);
`industry_l2` is RBICS level 2 (RBICS calls it **Sector**, 37 codes). The
fields are named by level because the vendor terms clash with GICS: in GICS
"Sector" is the top level, while in RBICS "Sector" is level 2. Info stores
codes only; names come from the enums / tables below.
`industry_l1`／`industry_l2` 對應 RBICS 第一層（Economy）與第二層（Sector）。
RBICS 的 Sector 是第二層，GICS 的 Sector 是第一層，因此欄位以層級命名。

Classification rules 分類規則:
- `classification_source="direct"`: the security's own RBICS record.
- `classification_source="parent"`: `PR`, `WRT`, `UNIT`, `RT` without their
  own classification borrow it from `underlying_code`.
- Otherwise all three fields are `None` (mostly `NOTE` and a few preferreds).
  ETFs carry the sponsor's classification, so for ETFs use `fund_category`.
  個股沒有分類時，PR／WRT／UNIT／RT 借用標的普通股分類（`parent`）；ETF 請看
  `fund_category`。

| L1 code | Enum | Name |
|--------:|------|------|
| 10 | `IndustryL1.BusinessServices` | Business Services |
| 15 | `IndustryL1.ConsumerServices` | Consumer Services |
| 20 | `IndustryL1.ConsumerCyclicals` | Consumer Cyclicals |
| 25 | `IndustryL1.Energy` | Energy |
| 30 | `IndustryL1.Finance` | Finance |
| 35 | `IndustryL1.Healthcare` | Healthcare |
| 40 | `IndustryL1.Industrials` | Industrials |
| 45 | `IndustryL1.NonEnergyMaterials` | Non-Energy Materials |
| 50 | `IndustryL1.ConsumerNonCyclicals` | Consumer Non-Cyclicals |
| 55 | `IndustryL1.Technology` | Technology |
| 60 | `IndustryL1.Telecommunications` | Telecommunications |
| 65 | `IndustryL1.Utilities` | Utilities |
| 90 | `IndustryL1.Other` | Other |
| 95 | `IndustryL1.NonCorporate` | Non-Corporate |

| L2 code | Enum | Name | L1 |
|--------:|------|------|---:|
| 1010 | `IndustryL2.BusinessServices` | Business Services | 10 |
| 1510 | `IndustryL2.HospitalityServices` | Hospitality Services | 15 |
| 1515 | `IndustryL2.MediaAndPublishingServices` | Media and Publishing Services | 15 |
| 2010 | `IndustryL2.ConsumerGoods` | Consumer Goods | 20 |
| 2015 | `IndustryL2.MiscellaneousRetail` | Miscellaneous Retail | 20 |
| 2020 | `IndustryL2.ConsumerVehiclesAndParts` | Consumer Vehicles and Parts | 20 |
| 2025 | `IndustryL2.ConsumerRetail` | Consumer Retail | 20 |
| 2510 | `IndustryL2.UpstreamEnergy` | Upstream Energy | 25 |
| 2515 | `IndustryL2.DownstreamAndMidstreamEnergy` | Downstream and Midstream Energy | 25 |
| 2520 | `IndustryL2.IntegratedOilAndGasExplorationAndProduction` | Integrated Oil and Gas Exploration and Production | 25 |
| 3010 | `IndustryL2.Banking` | Banking | 30 |
| 3015 | `IndustryL2.Insurance` | Insurance | 30 |
| 3020 | `IndustryL2.InvestmentServices` | Investment Services | 30 |
| 3025 | `IndustryL2.RealEstate` | Real Estate | 30 |
| 3030 | `IndustryL2.SpecialtyFinanceAndServices` | Specialty Finance and Services | 30 |
| 3510 | `IndustryL2.Biopharmaceuticals` | Biopharmaceuticals | 35 |
| 3515 | `IndustryL2.HealthcareServices` | Healthcare Services | 35 |
| 3520 | `IndustryL2.HealthcareEquipment` | Healthcare Equipment | 35 |
| 4010 | `IndustryL2.IndustrialManufacturing` | Industrial Manufacturing | 40 |
| 4015 | `IndustryL2.IndustrialServices` | Industrial Services | 40 |
| 4510 | `IndustryL2.ChemicalPlasticAndRubberMaterials` | Chemical, Plastic and Rubber Materials | 45 |
| 4515 | `IndustryL2.MiningAndMineralProducts` | Mining and Mineral Products | 45 |
| 4520 | `IndustryL2.ManufacturedProducts` | Manufactured Products | 45 |
| 5010 | `IndustryL2.FoodAndStaplesRetail` | Food and Staples Retail | 50 |
| 5015 | `IndustryL2.FoodAndTobaccoProduction` | Food and Tobacco Production | 50 |
| 5020 | `IndustryL2.HouseholdProducts` | Household Products | 50 |
| 5025 | `IndustryL2.HouseholdServices` | Household Services | 50 |
| 5510 | `IndustryL2.ElectronicComponentsAndManufacturing` | Electronic Components and Manufacturing | 55 |
| 5515 | `IndustryL2.Hardware` | Hardware | 55 |
| 5520 | `IndustryL2.SoftwareAndConsulting` | Software and Consulting | 55 |
| 6010 | `IndustryL2.Telecommunications` | Telecommunications | 60 |
| 6510 | `IndustryL2.Utilities` | Utilities | 65 |
| 9010 | `IndustryL2.CorporateOrOtherUnallocatedRevenue` | Corporate or Other Unallocated Revenue | 90 |
| 9015 | `IndustryL2.GeneralOrMultiIndustryRevenue` | General or Multi-Industry Revenue | 90 |
| 9510 | `IndustryL2.GovernmentsAndGovernmentalEntities` | Governments and Governmental Entities | 95 |
| 9515 | `IndustryL2.MembershipOrganizations` | Membership Organizations | 95 |
| 9520 | `IndustryL2.FinanciallyOperativeInstitutions` | Financially Operative Institutions | 95 |

`IndustryL2.<X>.l1` returns the parent `IndustryL1`.

#### fund_category 基金類別 (FactSet, ETF/ETN)

| Code | Enum | Name |
|-----:|------|------|
| 1 | `FundCategory.HedgeFundStrategies` | Hedge Fund Strategies |
| 3 | `FundCategory.AssetAllocation` | Asset Allocation |
| 4 | `FundCategory.Agriculture` | Agriculture |
| 5 | `FundCategory.BroadMarket` | Broad Market |
| 6 | `FundCategory.Energy` | Energy |
| 7 | `FundCategory.IndustrialMetals` | Industrial Metals |
| 8 | `FundCategory.PreciousMetals` | Precious Metals |
| 9 | `FundCategory.AustralianDollar` | Australian Dollar |
| 11 | `FundCategory.CanadianDollar` | Canadian Dollar |
| 16 | `FundCategory.IndianRupee` | Indian Rupee |
| 17 | `FundCategory.JapaneseYen` | Japanese Yen |
| 26 | `FundCategory.SizeAndStyle` | Size and Style |
| 27 | `FundCategory.Sector` | Sector |
| 34 | `FundCategory.Basket` | Basket |
| 35 | `FundCategory.TacticalTools` | Tactical Tools |
| 36 | `FundCategory.GlobalExUsBasket` | Global ex-US Basket |
| 44 | `FundCategory.HighDividendYield` | High Dividend Yield |
| 50 | `FundCategory.Metals` | Metals |
| 52 | `FundCategory.UsDollar` | U.S. Dollar |
| 56 | `FundCategory.CorporateAssetBacked` | Corporate, Asset-backed |
| 57 | `FundCategory.BroadMarketAssetBacked` | Broad Market, Asset-backed |
| 58 | `FundCategory.GovernmentTreasury` | Government, Treasury |
| 59 | `FundCategory.GovernmentNonNativeCurrency` | Government, Non-native currency |
| 60 | `FundCategory.GovernmentMortgageBacked` | Government, Mortgage-backed |
| 61 | `FundCategory.GovernmentLocalAuthorityMunicipal` | Government, Local Authority/Municipal |
| 62 | `FundCategory.GovernmentInflationLinked` | Government, Inflation-linked |
| 63 | `FundCategory.GovernmentBroadBased` | Government, Broad-based |
| 64 | `FundCategory.GovernmentAgency` | Government, Agency |
| 65 | `FundCategory.CorporatePreferred` | Corporate, Preferred |
| 66 | `FundCategory.CorporateConvertible` | Corporate, Convertible |
| 68 | `FundCategory.CorporateBroadBased` | Corporate, Broad-based |
| 69 | `FundCategory.CorporateBankLoans` | Corporate, Bank Loans |
| 70 | `FundCategory.BroadMarketBroadBased` | Broad Market, Broad-based |
| 71 | `FundCategory.Pair` | Pair |
| 75 | `FundCategory.StructuredOutcome` | Structured Outcome |

#### dividend_frequency 配息頻率

Stored as distributions per year. Only funds (ETF/ETN) carry it: the data comes
from the weekly ICE fund master, so individual stocks are always `None`.
存「每年配息次數」。只有基金（ETF/ETN）有值：資料來自每週一次的 ICE 基金主檔，個股一律為 `None`。

| Code | Enum | Meaning |
|-----:|------|---------|
| 12 | `DividendFrequency.Monthly` | Monthly 每月 |
| 4 | `DividendFrequency.Quarterly` | Quarterly 每季 |
| 2 | `DividendFrequency.SemiAnnual` | Semi-annual 每半年 |
| 1 | `DividendFrequency.Annual` | Annual 每年 |
| 0 | `DividendFrequency.Irregular` | Irregular 不定期 |
| `None` | — | Individual stock, no data, or no distribution 個股、無資料或不配息 |

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
