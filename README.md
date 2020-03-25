# Shioaji
![shioaji-logo](https://sinotrade.github.io/images/shioaji-logo-01.png)![sinopac-logo](https://www.sinotrade.com.tw/Images/logo.png)


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
- [Quickstarts](#quickstarts)
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
run with jupyter lab or notebook
```
docker run -p 8888:8888 sinotrade/shioaji:jupyter
```

## [Quickstarts](https://sinotrade.github.io/quickstart/)
## Initialization

```python
import shioaji as sj

api = sj.Shioaji()
accounts = api.login("YOUR_PERSON_ID", "YOUR_PASSWORD")
api.activate_ca(
    ca_path="/c/your/ca/path/Sinopac.pfx",
    ca_passwd="YOUR_CA_PASSWORD",
    person_id="Person of this Ca",
)
```
Just import our API library like other popular python library and new the instance to start using our API. Login your account and activate the certification then you can start placing order.


## [Streaming Market Data](https://sinotrade.github.io/tutor/market_data/streaming/)
```python
api.quote.subscribe(api.Contracts.Stocks["2330"], quote_type="tick")
api.quote.subscribe(api.Contracts.Stocks["2330"], quote_type="bidask")
api.quote.subscribe(api.Contracts.Futures["TXFC0"], quote_type="tick")
```

Subscribe the real time market data. Simplely pass contract into quote `subscribe` function and give the quote type will receive the streaming data.


## [Place Order](https://sinotrade.github.io/tutor/order/Stock_Trade_for_Trade/)

```python
contract = api.Contracts.Stocks["2890"]
order = api.Order(
    price=9.6,
    quantity=1,
    action="Buy",
    price_type="LMT",
    order_type="ROD",
    order_lot="Common",
    account=api.stock_account,
)
# or
order = api.Order(
    price=9.6,
    quantity=1,
    action=sj.constant.Action.Buy,
    price_type=sj.constant.TFTStockPriceType.LMT,
    order_type=sj.constant.TFTOrderType.ROD,
    order_lot=sj.constant.TFTStockOrderLot.Common,
    account=api.stock_account,
)
trade = api.place_order(contract, order)
```

Like the above subscribing market data using the contract, then need to define the order. Pass them into `place_order` function, then it will return the trade that describe the status of your order.

## Conclusion
This quickstart demonstrates how easy to use our package for native Python users. Unlike many other trading API is hard for Python developer. We focus on making more pythonic trading API for our users. 

More usage detail on document.

[![doc](https://img.shields.io/badge/docs%20-passing-orange.svg?style=for-the-badge)](https://sinotrade.github.io/)




## Communication
[![Gitter](https://badges.gitter.im/Sinotrade/Shioaji.svg)](https://gitter.im/Sinotrade/Shioaji?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
- Gitter: general chat, online discussions, collaboration etc.
- GitHub issues: bug reports, feature requests, install issues, RFCs, thoughts, etc.

## Releases and Contributing
Shioaji current state is Pre-Alpha, we expect no obvious bugs. Please let us know if you encounter a bug by [filing an issue](https://github.com/Sinotrade/Shioaji/issues).

We appreciate all suggestions. If you have any idea want us to implement, please discuss with us in gitter.

## The Team
Shioaji is currently maintained by [Sally](https://github.com/SsallyLin), [Yvictor](https://github.com/Yvictor), [Sam](https://github.com/linsamtw), [Sky Wu](https://github.com/strangenaiad) and [Po Chien Yang](https://github.com/ypochien) with major contributions.