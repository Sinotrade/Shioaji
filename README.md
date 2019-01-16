# Shioaji
![shioaji-logo](https://sinotrade.github.io/images/shioaji-logo-01.png)![sinopac-logo](http://www.sinotrade.com.tw/Images/logo.png)


[![PyPI - Status](https://img.shields.io/pypi/v/shioaji.svg?style=for-the-badge)](https://pypi.org/project/shioaji)
[![PyPI - Python Version](https://img.shields.io/pypi/pyversions/shioaji.svg?style=for-the-badge)]()
[![PyPI - Downloads](https://img.shields.io/pypi/dm/shioaji.svg?style=for-the-badge)](https://pypi.org/project/shioaji)
[![Build - Status](https://img.shields.io/badge/build-passing-brightgreen.svg?style=for-the-badge)]()

[![Coverage](https://img.shields.io/badge/coverage%20-99%25-yellowgreen.svg?style=for-the-badge)]()
[![Binder](https://img.shields.io/badge/launch-Tutorial-ff69b4.svg?style=for-the-badge)](https://mybinder.org/v2/gh/Sinotrade/Sinotrade.github.io/master?filepath=tutorial%2Fshioaji_tutorial.ipynb)
[![doc](https://img.shields.io/badge/docs%20-passing-orange.svg?style=for-the-badge)](https://sinotrade.github.io/)
[![Gitter](https://img.shields.io/badge/chat-%20on%20gitter-46bc99.svg?style=for-the-badge)](https://gitter.im/Sinotrade/Shioaji?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)


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
docker run -it sinotrade/shioaji:latest
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
sj.Shioaji?
```
    Init signature: sj.Shioaji(backend='http', simulation=True, proxies={}, currency='NTD')
    Docstring:    
    shioaji api 
    
    Functions:
        login 
        activate_ca
        list_accounts
        set_default_account
        get_account_margin 
        get_account_openposition
        get_account_settle_profitloss
        place_order
        update_order
        update_status
        list_trades
    
    Objects:
        Contracts
        Order
    Init docstring:
    initialize Shioaji to start trading
    
    Args:
        backend (str): {http, socket} 
            use http or socket as backend currently only support http, async socket backend coming soon.
        simulation (bool): 
            - False: to trading on real market (just use your Sinopac account to start trading)
            - True: become simulation account(need to contract as to open simulation account)
        proxies (dict): specific the proxies of your https
            ex: {'https': 'your-proxy-url'}
        currency (str): {NTX, USX, NTD, USD, HKD, EUR, JPY, GBP}
            set the default currency for display 
    File:           shioaji/shioaji.py
    Type:           type

```python
api = sj.Shioaji(backend='http', simulation=False)
```

```python
api.login?
```

    Signature: api.login(person_id, passwd)
    Docstring:
    login to trading server
    
    Args:
        person_id (str): Same as your eleader, ileader login id(usually your person ID)
        passwd  (str): the password of your eleader login password(not ca password)
    File:      shioaji/shioaji.py
    Type:     method
```python
person_id = 'SCCEIEFAJA'
```


```python
api.login(person_id=person_id, passwd='2222')
```


```python
api.fut_account
```




    FutureAccount(person_id='SCCEIEFAJA', broker_id='F002000', account_id='9104000', username='莊*芬')



### List all your account


```python
api.list_accounts()
```




    [Account(account_type='H', person_id='QCCAHIFFDH', broker_id='1300', account_id='09800762', username='n*m'),
     FutureAccount(person_id='SCCEIEFAJA', broker_id='F002000', account_id='9104000', username='莊*芬'),
     StockAccount(person_id='SCCEIEFAJA', broker_id='9A92', account_id='9802195', username='莊*芬')]



### Set your default trading account


```python
api.set_default_account(api.fut_account)
```

### Activate your cetifacation to start ordering

```python
api.activate_ca?
```

    Signature: api.activate_ca(ca_path, ca_passwd, person_id)
    Docstring:
    activate your ca for trading
    
    Args: 
        ca_path (str):
            the path of your ca, support both absloutely and relatively path, use same ca with eleader
        ca_passwd (str): password of your ca
        person_id (str): the ca belong which person ID
    File:     shioaji/shioaji.py
    Type:     method


```python
api.activate_ca(ca_path='../ca/Sinopac.pfx', ca_passwd='SCCEIEFAJA', person_id=person_id)
```

    Ca Initial Done.
    0



### Making Order object to place order


```python
api.Order?
```


    Init signature: api.Order(action, price_type, order_type, price, quantity, *args, **kwargs)
    Docstring:     
    The basic order object to place order
    
    Attributes:
        product_id (str): the code of product that order to placing
        action (srt): {B, S}, order action to buy or sell
            - B: buy
            - S: sell
        price_type (str): {LMT, MKT, MKP}, pricing type of order
            - LMT: limit
            - MKT: market
            - MKP: market range
        order_type (str): {ROD, IOC, FOK}, the type of order
            - ROD: Rest of Day
            - IOC: Immediate-or-Cancel
            - FOK: Fill-or-Kill
        octype (str): {' ', '0', '1', '6'}, the type or order to open new position or close position 
            - ' ': auto
            - '0': new position
            - '1': close position
            - '6': day trade
        price (float or int): the price of order
        quantity (int): the quantity of order
        account (:obj:Account): which account to place this order
        ca (binary): the ca of this order
    Init docstring:
    the __init__ method of order
    
    Args:
        product_id (str, optional): the code of product that order to placing 
                                    if not provide will gen from contract when placing order 
        action (srt): {B, S}, order action to buy or sell
            - B: buy
            - S: sell
        price_type (str): {LMT, MKT, MKP}, pricing type of order
            - LMT: limit
            - MKT: market
            - MKP: market range
        order_type (str): {ROD, IOC, FOK}, the type of order
            - ROD: Rest of Day
            - IOC: Immediate-or-Cancel
            - FOK: Fill-or-Kill
        octype (str, optional): {' ', '0', '1', '6'}, the type or order 
                                to open new position or close position 
                                if not provide will become auto mode 
            - ' ': auto
            - '0': new position
            - '1': close position
            - '6': day trade
        price (float or int): the price of order
        quantity (int): the quantity of order
    File:          shioaji/order.py
    Type:          type



#### using tab to direct get all the Order properties with autocomplete


```python
api.OrderProps.
```
    shioaji.backend.http.order.Order_props
```python
api.OrderProps.order_type.IOC
```

    'IOC'

#### using tab to direct get avaliable trading product with Contracts

```python
api.Contracts
```

    Contracts(Futures=(BRF, CAF, CBF, CCF, CDF, CEF, CFF, CGF, CHF, CJ1, CJF, CKF, CLF, CM1, CMF, CNF, CQF, CRF, CSF, CUF, CWF, CXF, CYF, CZ1, CZF, DC1, DCF, DDF, DE1, DEF, DF1, DFF, DGF, DHF, DJF, DKF, DLF, DN1, DNF, DOF, DP1, DPF, DQF, DSF, DUF, DVF, DWF, DX1, DXF, DYF, DZ1, DZF, EEF, EGF, EHF, EMF, EPF, ERF, ESF, EXF, EY1, EYF, FF1, FFF, FGF, FKF, FQF, FRF, FTF, FVF, FWF, FXF, FYF, FZF, GAF, GBF, GCF, GDF, GHF, GIF, GJF, GLF, GMF, GNF, GOF, GPF, GRF, GTF, GUF, GWF, GXF, GZF, HAF, HBF, HCF, HHF, HIF, HLF, HMF, HOF, HS1, HSF, HY1, HYF, I5F, IA1, IAF, IHF, IIF, IJF, IMF, IOF, IPF, IQF, IRF, ITF, IVF, IXF, IYF, IZF, JBF, JDF, JFF, JGF, JIF, JNF, JPF, JSF, JWF, JZF, KAF, KCF, KDF, KFF, KG1, KGF, KIF, KKF, KLF, KOF, KPF, KSF, KWF, LBF, LCF, LIF, LMF, LO1, LOF, LQF, LRF, LTF, LUF, LV1, LVF, LWF, LX1, LXF, LZF, MAF, MBF, MCF, MEF, MIF, MJF, MKF, ML1, MPF, MQF, MVF, MXF, MYF, NAF, NBF, NCF, NDF, NEF, NGF, NHF, NI1, NIF, NJF, NLF, NMF, NNF, NOF, NQF, NSF, NTF, NUF, NVF, NWF, NXF, NYF, NZF, OAF, OBF, OCF, ODF, OEF, OFF, OGF, OHF, OJF, OKF, OLF, OMF, ONF, OOF, OPF, OQF, ORF, OSF, OTF, OUF, OVF, OWF, OXF, OYF, OZF, PAF, PBF, RHF, RTF, SPF, T5F, TGF, TJF, TXF, UDF, XAF, XBF, XEF, XIF, XJF), Options=(CAO, CBA, CBO, CCO, CDO, CEO, CFO, CGA, CGO, CHO, CJA, CJO, CKO, CLA, CLO, CMA, CMO, CNO, CQO, CRO, CSO, CXO, CZA, CZO, DCO, DEA, DEO, DFA, DFO, DGO, DHA, DHO, DJO, DKA, DKO, DLO, DNA, DNO, DOO, DPO, DQO, DSO, DUO, DVO, DWO, DXA, DXO, GIA, GIO, GTO, GXO, HCO, IJA, IJO, LOA, LOO, NYA, NYO, NZO, OAO, OBO, OCO, OJO, OKO, OOO, OZA, OZO, RHO, RTO, TEO, TFO, TGO, TXO, XIO))


```python
api.Contracts.Futures
```

    (BRF, CAF, CBF, CCF, CDF, CEF, CFF, CGF, CHF, CJ1, CJF, CKF, CLF, CM1, CMF, CNF, CQF, CRF, CSF, CUF, CWF, CXF, CYF, CZ1, CZF, DC1, DCF, DDF, DE1, DEF, DF1, DFF, DGF, DHF, DJF, DKF, DLF, DN1, DNF, DOF, DP1, DPF, DQF, DSF, DUF, DVF, DWF, DX1, DXF, DYF, DZ1, DZF, EEF, EGF, EHF, EMF, EPF, ERF, ESF, EXF, EY1, EYF, FF1, FFF, FGF, FKF, FQF, FRF, FTF, FVF, FWF, FXF, FYF, FZF, GAF, GBF, GCF, GDF, GHF, GIF, GJF, GLF, GMF, GNF, GOF, GPF, GRF, GTF, GUF, GWF, GXF, GZF, HAF, HBF, HCF, HHF, HIF, HLF, HMF, HOF, HS1, HSF, HY1, HYF, I5F, IA1, IAF, IHF, IIF, IJF, IMF, IOF, IPF, IQF, IRF, ITF, IVF, IXF, IYF, IZF, JBF, JDF, JFF, JGF, JIF, JNF, JPF, JSF, JWF, JZF, KAF, KCF, KDF, KFF, KG1, KGF, KIF, KKF, KLF, KOF, KPF, KSF, KWF, LBF, LCF, LIF, LMF, LO1, LOF, LQF, LRF, LTF, LUF, LV1, LVF, LWF, LX1, LXF, LZF, MAF, MBF, MCF, MEF, MIF, MJF, MKF, ML1, MPF, MQF, MVF, MXF, MYF, NAF, NBF, NCF, NDF, NEF, NGF, NHF, NI1, NIF, NJF, NLF, NMF, NNF, NOF, NQF, NSF, NTF, NUF, NVF, NWF, NXF, NYF, NZF, OAF, OBF, OCF, ODF, OEF, OFF, OGF, OHF, OJF, OKF, OLF, OMF, ONF, OOF, OPF, OQF, ORF, OSF, OTF, OUF, OVF, OWF, OXF, OYF, OZF, PAF, PBF, RHF, RTF, SPF, T5F, TGF, TJF, TXF, UDF, XAF, XBF, XEF, XIF, XJF)


```python
api.Contracts.Futures.TXF
```

    TXF(TXF201903, TXF201906, TXF201809, TXF201810, TXF201811, TXF201812)

```python
api.Contracts.Futures.TXF.TXF201903
```
    Future(symbol='TXF201903', code='TXFC9', name='台指期貨', category='TXF', delivery_month='201903', underlying_kind='I', underlying_code='#001', unit=1.0)

```python
TXFR3 = api.Contracts.Futures.TXF.TXF201903
```

```python
sample_order = api.Order(product_id=TXFR3.code, 
                         price=9600,
                         action=api.OrderProps.action.Buy,
                         price_type=api.OrderProps.price_type.LMT,
                         order_type=api.OrderProps.order_type.ROD,
                         octype=api.OrderProps.octype.auto,
                         quantity=5,
                         account=api.fut_account,
                        )
sample_order
```

    Order(product_id='TXFC9', action='B', price_type='LMT', order_type='ROD', price=9600, quantity=5, account=FutureAccount(person_id='SCCEIEFAJA', broker_id='F002000', account_id='9104000', username='莊*芬')

```python
print(api.LimitOrder.__init__.__doc__)
```
     LimitOrder
    
            Args:
                product_id (str, optional): the code of product that order to placing 
                                            if not provide will gen from contract when placing order 
                action (srt): {B, S}, order action to buy or sell
                    - B: buy
                    - S: sell
                price (float or int): the price of order
                quantity (int): the quantity of order
                order_type (str, optional): {ROD, IOC, FOK}, the type of order
                    - ROD: Rest of Day
                    - IOC: Immediate-or-Cancel
                    - FOK: Fill-or-Kill
                octype (str, optional): {' ', '0', '1', '6'}, the type or order 
                                        to open new position or close position 
                                        if not provide will become auto mode 
                    - ' ': auto
                    - '0': new position
                    - '1': close position
                    - '6': day trade

```python
sample_limit_order = api.LimitOrder('B', 9700, 5)
sample_limit_order
```
    LimitOrder(action='B', order_type='ROD', price=9700, quantity=5)


### Using LimitOrder, MarketOrder, etc.

```python
print(api.MarketOrder.__init__.__doc__)
```

     MarketOrder
    
            Args:
                product_id (str, optional): the code of product that order to placing 
                                            if not provide will gen from contract when placing order 
                action (srt): {B, S}, order action to buy or sell
                    - B: buy
                    - S: sell
                quantity (int): the quantity of order
                order_type (str, optional): {IOC, FOK}, the type of order
                    - IOC: Immediate-or-Cancel
                    - FOK: Fill-or-Kill
                octype (str, optional): {' ', '0', '1', '6'}, the type or order 
                                        to open new position or close position 
                                        if not provide will become auto mode 
                    - ' ': auto
                    - '0': new position
                    - '1': close position
                    - '6': day trade

```python
sample_mkt_order = api.MarketOrder('B', 5)
sample_mkt_order
```

    MarketOrder(action='B', order_type='IOC', quantity=5)

### just pass Order object to place_order fuction to place order then will get the Trade object return

```python
trade = api.place_order(TXFR3, sample_order)
```


```python
trade
```

    Trade(contract=Future(symbol='TXF201903', code='TXFC9', name='台指期貨', category='TXF', delivery_month='201903', underlying_kind='I', underlying_code='#001', unit=1.0), order=Order(product_id='TXFC9', action='B', price_type='LMT', order_type='ROD', price=9600, quantity=5, account=FutureAccount(person_id='SCCEIEFAJA', broker_id='F002000', account_id='9104000', username='莊*芬')), status=OrderStatus(seqno='701124', order_id='7521840eb43914f94f98f025b1762e0b250ded21', status='PendingSubmit', order_datetime=datetime.datetime(2019, 1, 16, 12, 39, 28)))



### Update the trade object status to get the trade information


```python
api.update_status()
```


```python
trade
```

    Trade(contract=Future(symbol='TXF201903', code='TXFC9', name='台指期貨', category='TXF', delivery_month='201903', underlying_kind='I', underlying_code='#001', unit=1.0), order=Order(product_id='TXFC9', action='B', price_type='LMT', order_type='ROD', price=9600, quantity=5, account=FutureAccount(person_id='SCCEIEFAJA', broker_id='F002000', account_id='9104000', username='莊*芬')), status=OrderStatus(seqno='701124', ordno='ky00P', order_id='7521840eb43914f94f98f025b1762e0b250ded21', status='Submitted', status_code='0000', msg='ky00P', modified_price=9600.0, remaining=5, order_datetime=datetime.datetime(2019, 1, 16, 12, 39, 28)))



### Modify price or qty of trade


```python
trade = api.update_order(trade, price=9800, qty=1)
```


```python
trade
```

    Trade(contract=Future(symbol='TXF201903', code='TXFC9', name='台指期貨', category='TXF', delivery_month='201903', underlying_kind='I', underlying_code='#001', unit=1.0), order=Order(product_id='TXFC9', action='B', price_type='LMT', order_type='ROD', price=9600, quantity=5, account=FutureAccount(person_id='SCCEIEFAJA', broker_id='F002000', account_id='9104000', username='莊*芬')), status=OrderStatus(seqno='701124', ordno='ky00P', order_id='7521840eb43914f94f98f025b1762e0b250ded21', status='Submitted', status_code='0000', msg='ky00P', modified_price=9800.0, remaining=5, order_datetime=datetime.datetime(2019, 1, 16, 12, 39, 28)))


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
<table>
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
<table>
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
<table>
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
[![Gitter](https://badges.gitter.im/Sinotrade/Shioaji.svg)](https://gitter.im/Sinotrade/Shioaji?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
- Gitter: general chat, online discussions, collaboration etc.
- GitHub issues: bug reports, feature requests, install issues, RFCs, thoughts, etc.

## Releases and Contributing
Shioaji current state is Pre-Alpha, we expect no obvious bugs. Please let us know if you encounter a bug by [filing an issue](https://github.com/Sinotrade/Shioaji/issues).

We appreciate all suggestions. If you have any idea want us to implement, please discuss with us in gitter.

## The Team
Shioaji is currently maintained by [Yvictor](https://github.com/Yvictor), [TK Huang](https://github.com/TKHuang), [Sky Wu](https://github.com/strangenaiad) and [Po Chien Yang](https://github.com/ypochien) with major contributions.