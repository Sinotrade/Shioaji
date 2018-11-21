# Shioaji
![logo](http://www.sinotrade.com.tw/Images/logo.png)

Shioaji is sinopac provide the most pythonic api for trading the taiwan and global financial market.
You can use your favorite Python packages such as numpy, scipy, pandas, pytorch or tensorflow to build your own trading model with intergrated the shioaji api on cross platform.

We are in early-release alpha. Expect some adventures and rough edges.
- [Installation](#installation)
    - [Binaries](#binaries)
    - [Docker Image](#docker-image)
- [Getting Started](#getting-started)
- [Communication](#communication)
- [Releases and Contributing](#releases-and-contributing)
- [The Team](#the-team)


## Installation
### Binaries
simple using pip to install
```
pip install shioaji
```
### Docker Image
simple run with interactive mode in docker 
```
docker run -it shioaji:latest
```

## Getting Started

```python
from datetime import date, timedelta
import pandas as pd
```
### Just import Our api like other popular python library to get start
```python
import shioaji as sj
```
### Use Shioaji object to setup setting and login


```python
api = sj.Shioaji(backend='http', simulation=True)
```


```python
person_id = 'SCCEIEFAJA'
```


```python
api.login(person_id=person_id, passwd='2222')
```


```python
api.fut_account
```




    {'account': '9104000',
     'username': '莊*芬',
     'datacount': 0,
     'accttype': 'F',
     'broker_id': 'F002000',
     'idno': 'SCCEIEFAJA'}



### List all your account


```python
api.list_accounts()
```




    [{'account': '9104000',
      'username': '莊*芬',
      'datacount': 0,
      'accttype': 'F',
      'broker_id': 'F002000',
      'idno': 'SCCEIEFAJA'},
     {'account': '9802195',
      'username': '莊*芬',
      'datacount': 1,
      'accttype': 'S',
      'broker_id': '9A92',
      'idno': 'SCCEIEFAJA'},
     {'account': '09800762',
      'username': 'n*m',
      'datacount': 3,
      'accttype': 'H',
      'broker_id': '1300',
      'idno': 'QCCAHIFFDH'}]



### Set your default trading account


```python
api.set_default_account(api.fut_account)
```

### Activate your cetifacation to start ordering


```python
api.activate_ca(ca_path='../ca/Sinopac.pfx', ca_passwd='SCCEIEFAJA', person_id=person_id)
```

    Ca Initial Done.
    0



### Making Order object to place order


```python
api.Order?
```


    Init signature: api.Order(product_id, product_type, opt_type, price, price_type, order_bs, order_type, octype, quantity, account)
    Docstring: 
    create order object
    product_id: str 
        the product code
    product_type: {'F', 'O'}
        - F: future
        - O: option
    opt_type: {' ', 'C', 'P'}
        the option type Call or Put, leave blank if place future order
        - ' ': Future
        - 'C': Call
        - 'P': Put 
    price: float or int
        order price
    price_type: {LMT, MKT, MKP}
        - LMT: limit
        - MKT: market
        - MKP: market range
    order_bs: {'B', 'S'}, 
        - 'B': buy
        - 'S': sell
    order_type: {ROD, IOC, FOK}
        - ROD: Rest of Day
        - IOC: Immediate-or-Cancel
        - FOK: Fill-or-Kill
    octype: {' ', '0', '1', '6'}, 
        - ' ': auto
        - '0': new position
        - '1': close position
        - '6': day trade
    quantity: int



#### using tab to direct get all the Order properties with autocomplete


```python
api.Order_props.
```




    shioaji.backend.http.order.Order_props



#### using tab to direct get avaliable trading product with Contracts


```python
api.Contracts.Future.TXF.TXF201903
```




    Contract
        Code: TXFC9
        Detail:
            code: TXFC9
            deliverymonth: 201903
            poc: 
            eprice: 0.0
            ename: TXF
            category: TXF
            prod_kind: I
            csname: 台指期貨
            ostock: #001
            basic: 0001.000000




```python
sample_order = api.Order(product_id=api.Contracts.Future.TXF.TXF201903.code, 
                         product_type=api.Order_props.product_type.Future, 
                         opt_type=api.Order_props.opt_type.Future,
                         price=9600,
                         price_type=api.Order_props.price_type.LMT,
                         order_bs=api.Order_props.order_bs.Buy,
                         order_type=api.Order_props.order_type.ROD,
                         octype=api.Order_props.octype.auto,
                         quantity=5,
                         account=api.fut_account,
                        )
```

just pass Order object to place_order fuction to place order then will get the Trade object return


```python
trade = api.place_order(sample_order)
```



```python
trade
```




    Trade
        status: order_sent
            status_code: 
            errmsg: 
            product_id: TXFC9
            ordno: 
            seqno: 702330
            ord_bs: B
            price: 9600
            quantity: 5
            price_type: LMT
            account: {'account': '9104000', 'username': '莊*芬', 'datacount': 0, 'accttype': 'F', 'broker_id': 'F002000', 'idno': 'SCCEIEFAJA'}
            msg:                                                             
            trade_type: 01
            octype:  
            mttype: 0
            composit: 00
            ord_date: 20181119
            preord_date: 20181119
            ord_time: 15:45:48
            ord_type: ROD
            product_type: F
            opt_type:  



### Update the trade object status to get the trade information


```python
trade.update_status(api.client)
```


```python
trade
```




    Trade
        status: order_sent
            status_code: 0000
            errmsg: 
            product_id: TXFC9
            ordno: kY012
            seqno: 702330
            ord_bs: B
            price: 9600.0
            quantity: 5
            price_type: LMT
            account: {'account': '9104000', 'username': '莊*芬', 'datacount': 0, 'accttype': 'F', 'broker_id': 'F002000', 'idno': 'SCCEIEFAJA'}
            msg:                                                             
            trade_type: 01
            octype:  
            mttype: 0
            composit: 00
            ord_date: 20181119
            preord_date: 20181119
            ord_time: 15:45:48
            ord_type: ROD
            product_type: F
            opt_type:  



### Modify price or qty of trade


```python
trade = api.update_order(trade, price=9800, qty=1)
```


```python
trade
```




    Trade
        status: order_sent
            status_code: 0000
            errmsg: 
            product_id: TXFC9
            ordno: kY012
            seqno: 702330
            ord_bs: B
            price: 9800.0
            quantity: 5
            price_type: LMT
            account: {'account': '9104000', 'username': '莊*芬', 'datacount': 0, 'accttype': 'F', 'broker_id': 'F002000', 'idno': 'SCCEIEFAJA'}
            msg:                                                             
            trade_type: 01
            octype:  
            mttype: 0
            composit: 00
            ord_date: 20181119
            preord_date: 20181119
            ord_time: 15:45:48
            ord_type: ROD
            product_type: F
            opt_type:  



### Account Margin


```python
api.get_account_margin?
```
    Signature: api.get_account_margin(currency='NTD', margin_type='1', account={})
    Docstring:
    query margin    currency: {NTX, USX, NTD, USD, HKD, EUR, JPY, GBP}
    the margin calculate in which currency
        - NTX: 約當台幣
        - USX: 約當美金
        - NTD: 新台幣
        - USD: 美元
        - HKD: 港幣
        - EUR: 歐元
        - JPY: 日幣
        - GBP: 英鎊
    margin_type: {'1', '2'}
        query margin type
        - 1 : 即時
        - 2 : 風險


```python
account_margin = api.get_account_margin()
account_margin
```




    AccountMargin
        Currency: NTD
        Account: F0020009104000
        Detail:
            OrderPSecurity: 207000.0
            ProfitAccCount: 207000.0
            FProfit: 0.0
            FMissConProfit: 0.0
            OMissConProfit: 0.0
            OColse: 0.0
            OMarketPrice: 0.0
            OTodayDiff: 0.0
            HandCharge: 0.0
            TradeTax: 0.0
            Security: 0.0
            StartSecurity: 0.0
            UpKeepSecurity: 0.0
            Statistics: 99999.0
            Flow: 999.0
            orderBid: 0.0
            orderAsk: 0.0
            Conclusionbid: 0.0
            Conclusionask: 0.0
            YesterdayBalance: 207000.0
            PayMoney: 0.0
            Equity: 207000.0
            Ogain: 0.0
            exrate: 1.0
            xgdamt: 0.0
            agtamt: 0.0
            YesterdayEquity: 207000.0
            Munet: 0.0
            Cashamt: 207000.0
            Bapamt: 0.0
            Sapamt: 0.0
            Adps: 0.0
            Adamt: 0.0
            Ybaln: 207000.0



directly pass our AccountMargin object to pandas to using your model


```python
df_margin = pd.DataFrame([{**account_margin}])
df_margin
```




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>Adamt</th>
      <th>Adps</th>
      <th>Bapamt</th>
      <th>Cashamt</th>
      <th>Conclusionask</th>
      <th>Conclusionbid</th>
      <th>Equity</th>
      <th>FMissConProfit</th>
      <th>FProfit</th>
      <th>Flow</th>
      <th>...</th>
      <th>TradeTax</th>
      <th>UpKeepSecurity</th>
      <th>Ybaln</th>
      <th>YesterdayBalance</th>
      <th>YesterdayEquity</th>
      <th>agtamt</th>
      <th>exrate</th>
      <th>orderAsk</th>
      <th>orderBid</th>
      <th>xgdamt</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>0.0</td>
      <td>0.0</td>
      <td>0.0</td>
      <td>207000.0</td>
      <td>0.0</td>
      <td>0.0</td>
      <td>207000.0</td>
      <td>0.0</td>
      <td>0.0</td>
      <td>999.0</td>
      <td>...</td>
      <td>0.0</td>
      <td>0.0</td>
      <td>207000.0</td>
      <td>207000.0</td>
      <td>207000.0</td>
      <td>0.0</td>
      <td>1.0</td>
      <td>0.0</td>
      <td>0.0</td>
      <td>0.0</td>
    </tr>
  </tbody>
</table>
<p>1 rows × 34 columns</p>
</div>



# Get Open Position


```python
api.get_account_openposition?
```
    Signature: api.get_account_openposition(product_type='0', query_type='0', account={})
    Docstring:
    query open position
    product_type: {0, 1, 2, 3}
        filter product type of open position
        - 0: all
        - 1: future
        - 2: option
        - 3: usd base
    query_type: {0, 1}
        query return with detail or summary
        - 0: detail
        - 1: summary




```python
positions = api.get_account_openposition(query_type='1', account=api.fut_account)
positions
```




    AccountOpenPosition




```python
df_positions = pd.DataFrame(positions.data())
df_positions
```




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>Account</th>
      <th>Code</th>
      <th>CodeName</th>
      <th>ContractAverPrice</th>
      <th>Currency</th>
      <th>Date</th>
      <th>FlowProfitLoss</th>
      <th>MTAMT</th>
      <th>OTAMT</th>
      <th>OrderBS</th>
      <th>OrderNum</th>
      <th>OrderType</th>
      <th>RealPrice</th>
      <th>SettlePrice</th>
      <th>SettleProfitLoss</th>
      <th>StartSecurity</th>
      <th>UpKeepSecurity</th>
      <th>Volume</th>
      <th>paddingByte</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>FF0020009104000</td>
      <td>TXFA9</td>
      <td>台指期貨 01</td>
      <td>9508.4137</td>
      <td>NTD</td>
      <td>00000000</td>
      <td>4795201.620000</td>
      <td>6438000.000000</td>
      <td>8352000.000000</td>
      <td>B</td>
      <td></td>
      <td></td>
      <td>9784.0</td>
      <td>9784.00</td>
      <td>4795201.620000</td>
      <td>8352000.000000</td>
      <td>6438000.000000</td>
      <td>87.000000</td>
      <td></td>
    </tr>
    <tr>
      <th>1</th>
      <td>FF0020009104000</td>
      <td>XJFF9</td>
      <td>日圓期貨 06</td>
      <td>80.0000</td>
      <td>JPY</td>
      <td>00000000</td>
      <td>31400.000000</td>
      <td>47000.000000</td>
      <td>61000.000000</td>
      <td>B</td>
      <td></td>
      <td></td>
      <td>0.0</td>
      <td>81.57</td>
      <td>31400.000000</td>
      <td>61000.000000</td>
      <td>47000.000000</td>
      <td>1.000000</td>
      <td></td>
    </tr>
    <tr>
      <th>2</th>
      <td>FF0020009104000</td>
      <td>TXO08000L8</td>
      <td>台指選擇權 8000 C 12</td>
      <td>1870.0000</td>
      <td>NTD</td>
      <td>00000000</td>
      <td>-14000.000000</td>
      <td>0.000000</td>
      <td>0.000000</td>
      <td>B</td>
      <td></td>
      <td></td>
      <td>1730.0</td>
      <td>1810.00</td>
      <td>-6000.000000</td>
      <td>0.000000</td>
      <td>0.000000</td>
      <td>2.000000</td>
      <td></td>
    </tr>
    <tr>
      <th>3</th>
      <td>FF0020009104000</td>
      <td>TXO09200L8</td>
      <td>台指選擇權 9200 C 12</td>
      <td>720.0000</td>
      <td>NTD</td>
      <td>00000000</td>
      <td>11250.000000</td>
      <td>147000.000000</td>
      <td>162000.000000</td>
      <td>S</td>
      <td></td>
      <td></td>
      <td>645.0</td>
      <td>660.00</td>
      <td>9000.000000</td>
      <td>162000.000000</td>
      <td>147000.000000</td>
      <td>3.000000</td>
      <td></td>
    </tr>
    <tr>
      <th>4</th>
      <td>FF0020009104000</td>
      <td>TXO09400X8</td>
      <td>台指選擇權 9400 P 12</td>
      <td>199.0000</td>
      <td>NTD</td>
      <td>00000000</td>
      <td>21200.000000</td>
      <td>57600.000000</td>
      <td>65600.000000</td>
      <td>S</td>
      <td></td>
      <td></td>
      <td>93.0</td>
      <td>93.00</td>
      <td>21200.000000</td>
      <td>65600.000000</td>
      <td>57600.000000</td>
      <td>4.000000</td>
      <td></td>
    </tr>
    <tr>
      <th>5</th>
      <td>FF0020009104000</td>
      <td>TXO10200L8</td>
      <td>台指選擇權 10200 C 12</td>
      <td>111.0000</td>
      <td>NTD</td>
      <td>00000000</td>
      <td>33550.000000</td>
      <td>125950.000000</td>
      <td>147950.000000</td>
      <td>S</td>
      <td></td>
      <td></td>
      <td>50.0</td>
      <td>50.00</td>
      <td>33550.000000</td>
      <td>147950.000000</td>
      <td>125950.000000</td>
      <td>11.000000</td>
      <td></td>
    </tr>
  </tbody>
</table>
</div>



### Get Settle ProfitLoss


```python
api.get_account_settle_profitloss?
```
    Signature: api.get_account_settle_profitloss(product_type='0', summary='Y', start_date='', end_date='', currency='', account={})
    Docstring:
    query settlement profit loss
    product_type: {0, 1, 2}
        filter product type of open position
        - 0: all
        - 1: future
        - 2: option
    summary: {Y, N}
        query return with detail or summary
        - Y: summary
        - N: detail
    start_date: str
        the start date of query range format with %Y%m%d
        ex: 20180101
    end_date: str
        the end date of query range format with %Y%m%d
        ex: 20180201
    currency: {NTD, USD, HKD, EUR, CAD, BAS}
        the profit loss calculate in which currency
        - NTD: 新台幣
        - USD: 美元
        - HKD: 港幣
        - EUR: 歐元
        - CAD: 加幣 
        - BAS: 基幣




```python
st_date = (date.today() - timedelta(days=60)).strftime('%Y%m%d')
settle_profitloss = api.get_account_settle_profitloss(summary='Y', start_date=st_date)
settle_profitloss
```

    AccountSettleProfitLoss


```python
df_profitloss = pd.DataFrame(settle_profitloss.data())
df_profitloss
```




<div>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>account</th>
      <th>averagePrice</th>
      <th>code</th>
      <th>codeName</th>
      <th>currency</th>
      <th>floatProfitLoss</th>
      <th>handCharge</th>
      <th>ord_bs</th>
      <th>ord_type</th>
      <th>ordno</th>
      <th>ordno_b</th>
      <th>settleAvgPrc</th>
      <th>settleDate</th>
      <th>settleVolume</th>
      <th>tFlag</th>
      <th>tdate</th>
      <th>tradeProfitLoss</th>
      <th>tradeTax</th>
      <th>unVolume</th>
      <th>volume</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>F0020009104000</td>
      <td>9900.0</td>
      <td>TXFK8</td>
      <td>台指期貨 11</td>
      <td>NTD</td>
      <td>460.000000</td>
      <td>60.000000</td>
      <td>S</td>
      <td>00</td>
      <td>kY002</td>
      <td>kY003</td>
      <td>9897.0</td>
      <td>20181022</td>
      <td>1.000000</td>
      <td>1</td>
      <td>20181022</td>
      <td>600.000000</td>
      <td>80.000000</td>
      <td>0.000000</td>
      <td>1.000000</td>
    </tr>
  </tbody>
</table>
</div>



## Communication

## Releases and Contributing

## The Team

