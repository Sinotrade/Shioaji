# Shioaji
![shioaji-logo](https://sinotrade.github.io/images/shioaji-logo-01.png)![sinopac-logo](https://www.sinotrade.com.tw/Images/logo.png)


[![PyPI - Status](https://img.shields.io/pypi/v/shioaji.svg?style=for-the-badge)](https://pypi.org/project/shioaji)
[![PyPI - Python Version](https://img.shields.io/pypi/pyversions/shioaji.svg?style=for-the-badge)]()
[![PyPI - Downloads](https://img.shields.io/pypi/dm/shioaji.svg?style=for-the-badge)](https://pypi.org/project/shioaji)
[![Coverage](https://img.shields.io/badge/coverage%20-99%25-yellowgreen.svg?style=for-the-badge)]()
[![doc](https://img.shields.io/badge/docs%20-passing-orange.svg?style=for-the-badge)](https://sinotrade.github.io/)
[![Telegram](https://img.shields.io/badge/chat-%20on%20telegram-blue.svg?style=for-the-badge)](https://t.me/joinchat/973EyAQlrfthZTk1)
[![Discord](https://img.shields.io/badge/chat-%20on%20discord-5865F2.svg?style=for-the-badge)](https://discord.gg/5nzmWCTnG7)

[繁體中文](README.zh-TW.md)

Shioaji is a trading API provided by Sinopac that offers a comprehensive and user-friendly platform for accessing the Taiwan financial markets. Shioaji is a **cross-language, cross-platform** universal trading platform — accessible through native Python bindings (`import shioaji as sj`) or any HTTP-capable language (JavaScript/TypeScript, Go, C/C++, C#, Rust, Java/Kotlin) for trading stocks, futures, options, and combo orders. On the Python side, Shioaji integrates seamlessly with familiar packages such as numpy, scipy, pandas, pytorch, and tensorflow for building custom trading models; on the HTTP side, a built-in OpenAPI interactive document, SSE real-time streaming, and a visual Dashboard provide live monitoring of server status, SSE connections, CA certificates, accounts, and API usage. Whether for traders new to the world of programmatic trading or experienced developers seeking a more powerful platform, Shioaji is built to deliver. [Sign up for a free account today and start trading with confidence.](https://sinotrade.github.io/tutor/prepare/open_account)

> ✨ **The first Taiwan trading API with AI coding agent skill support** — [Claude Code & Codex CLI](#ai-coding-agent-skills)

- [AI Coding Agent Skills](#ai-coding-agent-skills)
- [Installation](#installation)
    - [Python Package](#install-python)
    - [CLI Tool](#install-cli)
    - [Standalone Installer](#install-binary)
- [Quickstart](#quickstart)
    - [Python](#quickstart-python)
    - [Cross-language](#quickstart-http)
    - [CLI](#quickstart-cli)
- [Conclusion](#conclusion)
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

#### Codex
```bash
codex plugin marketplace add Sinotrade/Shioaji
codex plugin add shioaji@sinotrade
```

#### Cursor

Install from the [Cursor Marketplace](https://cursor.com/marketplace) after the Shioaji plugin is published, or submit the repository through the [Cursor publisher flow](https://cursor.com/marketplace/publish) for review.

#### Multi-platform Installers (Cursor, Windsurf, Copilot, Codex, and more)
```bash
npx skills add Sinotrade/Shioaji                # skills.sh - 18+ agents
npx skillkit install Sinotrade/Shioaji          # skillkit - 32+ agents
npx openskills install Sinotrade/Shioaji        # openskills - universal
```

## Installation

Expand the section that matches your installation preference.

<a id="install-python"></a>
<details>
<summary><strong>Python Package</strong></summary>

```bash
# uv (recommended)
uv add shioaji

# pip
pip install shioaji
```

</details>

<a id="install-cli"></a>
<details>
<summary><strong>CLI Tool</strong></summary>

```bash
uv tool install shioaji
shioaji --help
```

</details>

<a id="install-binary"></a>
<details>
<summary><strong>Standalone Installer</strong></summary>

**Linux / macOS:**
```bash
# Stable
curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | sh

# Pre-release
curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | CHANNEL=prerelease sh

# Specific version
curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | VERSION=v1.5.5 sh
```

**Windows (PowerShell):**
```bash
# Stable
irm https://github.com/Sinotrade/Shioaji/releases/latest/download/install.ps1 | iex

# Pre-release
$env:CHANNEL="prerelease"; irm https://github.com/Sinotrade/Shioaji/releases/latest/download/install.ps1 | iex
```

</details>

## [Quickstart](https://sinotrade.github.io/quickstart/)

Expand the section that matches your preferred development language.

<a id="quickstart-python"></a>
<details>
<summary><strong>Python</strong></summary>

### Initialization (login + activate certificate)

```python
import shioaji as sj

api = sj.Shioaji()
accounts = api.login(api_key="YOUR_KEY", secret_key="YOUR_SECRET")
api.activate_ca(
    ca_path="/c/your/ca/path/Sinopac.pfx",
    ca_passwd="YOUR_CA_PASSWORD",
)
```

Just import the API library like other popular Python packages and create the instance to start using it. After logging in, the API is ready for market data queries; once the certificate is activated, order placement is enabled.

### Subscribe to Streaming Market Data

```python
api.subscribe(api.Contracts.Stocks["2330"], quote_type="tick")
api.subscribe(api.Contracts.Stocks["2330"], quote_type="bid_ask")
api.subscribe(api.Contracts.Futures["TXFC0"], quote_type="tick")
```

Subscribe to real-time market data. Pass a contract into the `subscribe` function and specify a `quote_type` to begin receiving streaming data.

### Place Order

```python
contract = api.Contracts.Stocks["2890"]
order = sj.StockOrder(
    price=9.6,
    quantity=1,
    action=sj.Action.Buy,
    price_type=sj.StockPriceType.LMT,
    order_type=sj.OrderType.ROD,
    order_lot=sj.StockOrderLot.Common,
    account=api.stock_account,
)
trade = api.place_order(contract, order)
```

As with subscribing to market data using a contract, an order must first be defined and then passed alongside the contract into the `place_order` function. The function returns a `trade` object representing the order's status.

</details>

<a id="quickstart-http"></a>
<details>
<summary><strong>Cross-language</strong></summary>

### Start the Server

```bash
shioaji server start
```

Once the server is running, all trading capabilities are exposed as RESTful endpoints accessible from any HTTP-capable language (JavaScript, Go, C#, Java, Rust, C/C++, etc.).

Verify that the server has started successfully:

```bash
curl http://localhost:8080/api/v1/health
```

### Getting Started

Once the server is running, the following entry points are available:

| Purpose | URL |
|---------|-----|
| Dashboard (live monitoring & management) | `http://localhost:8080/` |
| OpenAPI document (browse API, run tests in-browser) | `http://localhost:8080/docs` |
| Custom apps (entry point for self-uploaded web apps) | `http://localhost:8080/apps/<name>/` |


Open `/docs` to browse all endpoints, inspect request/response schemas, generate code samples in multiple languages, and test directly from the browser.

### Custom Web Apps

Custom web apps can be uploaded from the Dashboard's **Custom Apps** card and run alongside the Dashboard; once uploaded, an app is served at `http://localhost:8080/apps/<name>/`.

- **Supported formats**: a single HTML file, or a build output folder from frontend frameworks such as Vite / React / Vue (containing `index.html`).
- **Upload steps**: log in to the Dashboard → click **Custom Apps** → **Upload** → select the file or folder → set the application name `<name>`.
- **Project template**: [`@sinotrade/create-shioaji-app`](https://www.npmjs.com/package/@sinotrade/create-shioaji-app) — scaffolds a Shioaji frontend project with one command.

</details>

<a id="quickstart-cli"></a>
<details>
<summary><strong>CLI</strong></summary>

The `shioaji` CLI provides direct server management, market data queries, and order placement.

```bash
shioaji --help        # list all commands
shioaji tree --all    # show full command tree (with parameters and descriptions)
```

**Server Management**

| Purpose | Command |
|---------|---------|
| Start HTTP server (simulation mode) | `shioaji server start` |
| Start HTTP server (production mode) | `shioaji server start --production` |
| Check mode and authentication status | `shioaji server check` |
| Show daemon status | `shioaji server status` |
| Stop daemon | `shioaji server stop` |

</details>

## Conclusion

This quickstart shows the multiple ways to access Shioaji — from native Python, HTTP API, and CLI to custom web apps. The focus is on building an easy-to-use, cross-language trading API that lets any developer trade Taiwan's financial markets with confidence.

For more usage details, see

[![doc](https://img.shields.io/badge/docs%20-passing-orange.svg?style=for-the-badge)](https://sinotrade.github.io/)


## Communication
[![Telegram](https://img.shields.io/badge/chat-%20on%20telegram-blue.svg?style=for-the-badge)](https://t.me/joinchat/973EyAQlrfthZTk1)
[![Discord](https://img.shields.io/badge/chat-%20on%20discord-5865F2.svg?style=for-the-badge)](https://discord.gg/5nzmWCTnG7)

## Releases and Contributing
Shioaji has a 14 day release cycle. See the release [change log](https://sinotrade.github.io/release/). Please let us know if you encounter a bug by [filing an issue](https://github.com/Sinotrade/Shioaji/issues).

We appreciate all suggestions. If you have any idea you'd like to see implemented, feel free to discuss with us on Telegram or Discord.

## The Team
Shioaji is currently maintained by [Sally](https://github.com/SsallyLin), [Yvictor](https://github.com/Yvictor), [Zecheng](https://github.com/zechengwang724) and [Po Chien Yang](https://github.com/ypochien) with major contributions.
