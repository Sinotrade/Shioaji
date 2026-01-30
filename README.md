# Shioaji
![shioaji-logo](https://sinotrade.github.io/images/shioaji-logo-01.png)![sinopac-logo](https://www.sinotrade.com.tw/Images/logo.png)


[![PyPI - Status](https://img.shields.io/pypi/v/shioaji.svg?style=for-the-badge)](https://pypi.org/project/shioaji)
[![PyPI - Python Version](https://img.shields.io/pypi/pyversions/shioaji.svg?style=for-the-badge)]()
[![PyPI - Downloads](https://img.shields.io/pypi/dm/shioaji.svg?style=for-the-badge)](https://pypi.org/project/shioaji)
[![Coverage](https://img.shields.io/badge/coverage%20-99%25-yellowgreen.svg?style=for-the-badge)]()
[![Binder](https://img.shields.io/badge/launch-Tutorial-ff69b4.svg?style=for-the-badge)](https://mybinder.org/v2/gh/Sinotrade/Sinotrade.github.io/master?filepath=tutorial%2Fshioaji_tutorial.ipynb)
[![doc](https://img.shields.io/badge/docs%20-passing-orange.svg?style=for-the-badge)](https://sinotrade.github.io/)
[![Telegram](https://img.shields.io/badge/chat-%20on%20telegram-blue.svg?style=for-the-badge)](https://t.me/joinchat/973EyAQlrfthZTk1)

Shioaji is a trading API provided by Sinopac that offers a comprehensive and user-friendly platform for accessing the Taiwan financial markets. With Shioaji, you can trade a variety of financial instruments including stocks, futures, and options using your favorite Python packages such as numpy, scipy, pandas, pytorch, or tensorflow to build your own custom trading models. The platform is easy to use and intuitive, with advanced charting tools, real-time market data, and a customizable interface that allows you to tailor your trading experience to your specific needs. Shioaji is fast and efficient, with a high-performance core implemented in C++ and using FPGA event broker technology, and it is the first Python trading API in Taiwan that is compatible with Linux and Mac, making it a truly cross-platform solution. Whether you are a beginner looking to get started in the world of trading or an experienced trader looking for a more powerful platform, Shioaji has something to offer. [Sign up for a free account today and start trading with confidence.](https://sinotrade.github.io/tutor/prepare/open_account)

> ✨ **First Taiwan trading API with AI coding agent skill support** — [Claude Code & Codex CLI](#ai-coding-agent-skills)

- [AI Coding Agent Skills](#ai-coding-agent-skills)
- [Installation](#installation)
    - [Binaries](#binaries)
    - [Docker Image](#docker-image)
- [Quickstarts](#quickstarts)
- [Communication](#communication)
- [Releases and Contributing](#releases-and-contributing)
- [The Team](#the-team)


## AI Coding Agent Skills

Shioaji is the **first Taiwan trading API with AI coding agent skill support**. Get AI-assisted guidance on using the Shioaji API.

#### Claude Code
```bash
claude plugin marketplace add Sinotrade/Shioaji
claude plugin install shioaji
```

#### Universal Installers (Cursor, Windsurf, Copilot, Codex, and more)
```bash
npx skills add Sinotrade/Shioaji                # skills.sh - 18+ agents
npx skillkit install Sinotrade/Shioaji          # skillkit - 32+ agents
npx openskills install Sinotrade/Shioaji        # openskills - universal
```

## Installation
### Binaries
simple using pip to install
```
pip install shioaji
```
update shioaji with 

```
pip install -U shioaji
```

### uv
using uv to install
```
uv add shioaji 
```
install speed version
```
uv add shioaji --extra speed
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
accounts = api.login("YOUR_TOKEN", "YOUR_SECRET_KEY")
api.activate_ca(
    ca_path="/c/your/ca/path/Sinopac.pfx",
    ca_passwd="YOUR_CA_PASSWORD",
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


## [Place Order](https://sinotrade.github.io/tutor/order/Stock/)

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
    price_type=sj.constant.StockPriceType.LMT,
    order_type=sj.constant.OrderType.ROD,
    order_lot=sj.constant.StockOrderLot.Common,
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
[![Telegram](https://img.shields.io/badge/chat-%20on%20telegram-blue.svg?style=for-the-badge)](https://t.me/joinchat/973EyAQlrfthZTk1)

## Releases and Contributing
Shioaji has a 14 day release cycle. See the release [change log](https://sinotrade.github.io/release/). Please let us know if you encounter a bug by [filing an issue](https://github.com/Sinotrade/Shioaji/issues).

We appreciate all suggestions. If you have any idea want us to implement, please discuss with us in gitter.

## The Team
Shioaji is currently maintained by [Sally](https://github.com/SsallyLin), [Yvictor](https://github.com/Yvictor), [CC.Chiao](https://github.com/luckchiao) and [Po Chien Yang](https://github.com/ypochien) with major contributions.