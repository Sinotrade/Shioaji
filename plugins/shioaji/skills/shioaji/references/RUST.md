# Rust HTTP/SSE Client Patterns

Transport guide for building Rust applications that call the Shioaji HTTP API with `reqwest` and consume SSE streams with `reqwest-eventsource`.

本文件說明 Rust 如何送 HTTP request、處理 JSON response、消費 SSE 串流。它不是 endpoint payload 或 response schema catalog。

---

## Table of Contents / 目錄

1. [Prerequisites / 前置條件](#1-prerequisites--前置條件)
2. [Project Setup / 專案建置](#2-project-setup--專案建置)
3. [Project Layout / 專案結構](#3-project-layout--專案結構)
4. [API Client Module / API 客戶端模組](#4-api-client-module--api-客戶端模組)
5. [HTTP Examples / HTTP 範例](#5-http-examples--http-範例)
6. [SSE Streaming / SSE 即時串流](#6-sse-streaming--sse-即時串流)
7. [OpenAPI Client Generation / OpenAPI 客戶端生成](#7-openapi-client-generation--openapi-客戶端生成)
8. [Complete Example / 完整範例](#8-complete-example--完整範例)

---

## 1. Prerequisites / 前置條件

Start the Shioaji HTTP server first:

先啟動 Shioaji HTTP 伺服器：

```bash
uv tool install shioaji
# or: curl -fsSL https://github.com/Sinotrade/Shioaji/releases/latest/download/install.sh | sh
shioaji server start   # simulation mode by default
```

Before starting the server, configure `.env` in the server working directory or export equivalent variables: `SJ_API_KEY`, `SJ_SEC_KEY`, `SJ_CA_PATH`, `SJ_CA_PASSWD`, and `SJ_PRODUCTION`. Use `SJ_PRODUCTION=false` while testing language clients unless the user explicitly needs production mode. See [PREPARE.md](PREPARE.md) for full setup, certificate, and `.env` details.

The server runs at `http://localhost:8080` with all endpoints under `/api/v1/`.

This is a transport/client-pattern guide: how to send HTTP requests, parse responses, handle errors, and consume SSE in Rust. It is not an endpoint payload or response schema catalog.

Use the matching functional reference for workflow, payload rules, response shapes, and branching decisions. Use [HTTP_API.md](HTTP_API.md) for endpoint inventory. The hand-written structs below are starter transport types; fetch `/openapi.json` for production clients.

This language guide is transport-only. Do not restate or override shared HTTP rules here: order update/cancel `trade_id`, `order_deal_event` over SSE, simulation vs production, and SSE payload field types are governed by [HTTP_API.md](HTTP_API.md) and the matching functional reference.

## 2. Project Setup / 專案建置

```bash
cargo init my-trading-app
cd my-trading-app
```

**Cargo.toml**:

```toml
[package]
name = "my-trading-app"
version = "0.1.0"
edition = "2021"

[dependencies]
reqwest = { version = "0.12", features = ["json"] }
reqwest-eventsource = "0.6"
rust_decimal = { version = "1", features = ["serde-with-str"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
futures-util = "0.3"
```

## 3. Project Layout / 專案結構

```
my-trading-app/
├── src/
│   ├── client.rs       # API client
│   ├── types.rs        # Request/response types
│   ├── stream.rs       # SSE connection
│   ├── strategies/     # User trading logic
│   │   └── mod.rs
│   └── main.rs
└── Cargo.toml
```

## 4. API Client Module / API 客戶端模組

**src/types.rs** -- typed request and response structs:

```rust
use serde::{Deserialize, Serialize};

/// Contract identifier used across multiple endpoints
#[derive(Debug, Serialize, Deserialize)]
pub struct ContractRef {
    pub security_type: String,   // "STK", "FUT", "OPT", or "IND"
    pub exchange: String,        // "TSE", "OTC", "TAIFEX"
    pub code: String,            // e.g. "2330"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_code: Option<String>,
}

/// POST /api/v1/data/snapshots request body
#[derive(Debug, Serialize)]
pub struct SnapshotsRequest {
    pub contracts: Vec<ContractRef>,
}

/// Snapshot response item
#[derive(Debug, Deserialize)]
pub struct Snapshot {
    pub datetime: String,
    pub code: String,
    pub close: f64,
    pub volume: i64,
    pub total_volume: i64,
}

/// Account info from GET /api/v1/auth/accounts
#[derive(Debug, Deserialize)]
pub struct Account {
    pub account_id: String,
    pub signed: bool,
}

/// POST /api/v1/order/place_order request body
#[derive(Debug, Serialize)]
pub struct PlaceOrderRequest {
    pub contract: ContractRef,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stock_order: Option<StockOrder>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub futures_order: Option<FuturesOrder>,
}

#[derive(Debug, Serialize)]
pub struct StockOrder {
    pub action: String,           // "Buy" or "Sell"
    pub price: f64,
    pub quantity: i32,
    pub price_type: String,       // "LMT" or "MKT"
    pub order_type: String,       // "ROD", "IOC", "FOK"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub order_lot: Option<String>, // "Common", "Odd", "IntradayOdd"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub order_cond: Option<String>, // "Cash", "MarginTrading", "ShortSelling"
}

#[derive(Debug, Serialize)]
pub struct FuturesOrder {
    pub action: String,           // "Buy" or "Sell"
    pub price: f64,
    pub quantity: i32,
    pub price_type: String,       // "LMT", "MKT", or "MKP"
    pub order_type: String,       // "ROD", "IOC", "FOK"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub octype: Option<String>,   // "Auto", "New", "Cover", "DayTrade"; HTTP also accepts "NewPosition"
}

/// Place order response. The real Trade contains nested contract/order/status;
/// fill records, when present, are inside status.deals.
#[derive(Debug, Deserialize)]
pub struct Trade {
    pub contract: serde_json::Value,
    pub order: serde_json::Value,
    pub status: serde_json::Value,
}

/// SSE subscribe request
#[derive(Debug, Serialize, Deserialize)]
pub struct SubscribeRequest {
    pub security_type: String,
    pub exchange: String,
    pub code: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_code: Option<String>,
    pub quote_type: String,       // "Tick", "BidAsk", "Quote"
}

#[derive(Debug, Deserialize)]
pub struct SubscriptionResponse {
    pub success: bool,
    pub message: String,
    pub subscription: Option<SubscribeRequest>,
}

/// Tick data from SSE stream
/// Price/amount fields are JSON strings — use rust_decimal to parse with precision
#[derive(Debug, Deserialize)]
pub struct TickData {
    pub code: String,
    pub date: String,
    pub time: String,
    #[serde(with = "rust_decimal::serde::str")]
    pub open: rust_decimal::Decimal,
    #[serde(with = "rust_decimal::serde::str")]
    pub close: rust_decimal::Decimal,
    #[serde(with = "rust_decimal::serde::str")]
    pub high: rust_decimal::Decimal,
    #[serde(with = "rust_decimal::serde::str")]
    pub low: rust_decimal::Decimal,
    pub volume: u64,
    pub total_volume: u64,
    pub tick_type: u32,
    pub simtrade: bool,
}
```

**src/client.rs** -- the API client wrapping `reqwest::Client`:

```rust
use crate::types::*;
use reqwest::Client;

const BASE_URL: &str = "http://localhost:8080";

pub struct ShioajiClient {
    client: Client,
    base_url: String,
}

impl ShioajiClient {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: BASE_URL.to_string(),
        }
    }

    pub fn with_base_url(base_url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: base_url.to_string(),
        }
    }

    /// GET /api/v1/auth/accounts
    pub async fn list_accounts(&self) -> Result<Vec<Account>, reqwest::Error> {
        self.client
            .get(format!("{}/api/v1/auth/accounts", self.base_url))
            .send()
            .await?
            .json()
            .await
    }

    /// POST /api/v1/data/snapshots
    pub async fn snapshots(
        &self,
        contracts: Vec<ContractRef>,
    ) -> Result<Vec<Snapshot>, reqwest::Error> {
        self.client
            .post(format!("{}/api/v1/data/snapshots", self.base_url))
            .json(&SnapshotsRequest { contracts })
            .send()
            .await?
            .json()
            .await
    }

    /// POST /api/v1/order/place_order
    pub async fn place_order(
        &self,
        request: PlaceOrderRequest,
    ) -> Result<Trade, reqwest::Error> {
        self.client
            .post(format!("{}/api/v1/order/place_order", self.base_url))
            .json(&request)
            .send()
            .await?
            .json()
            .await
    }

    /// POST /api/v1/stream/subscribe
    pub async fn subscribe(
        &self,
        request: SubscribeRequest,
    ) -> Result<SubscriptionResponse, reqwest::Error> {
        self.client
            .post(format!("{}/api/v1/stream/subscribe", self.base_url))
            .json(&request)
            .send()
            .await
            ?.json()
            .await
    }
}
```

## 5. HTTP Examples / HTTP 範例

### List Accounts / 列出帳戶

```rust
let client = ShioajiClient::new();
let accounts = client.list_accounts().await?;
for acc in &accounts {
    println!("Account: {} (signed: {})", acc.account_id, acc.signed);
}
```

### Snapshots / 快照查詢

```rust
let snapshots = client
    .snapshots(vec![ContractRef {
        security_type: "STK".into(),
        exchange: "TSE".into(),
        code: "2330".into(),
        target_code: None,
    }])
    .await?;

for snap in &snapshots {
    println!("{}: close={}, volume={}", snap.code, snap.close, snap.total_volume);
}
```

### Place Order / 下單

Keep order examples disabled in runnable code. Confirm account, production/simulation mode, payload rules, response status, and `order_deal_event` handling in [ORDERS.md](ORDERS.md) before enabling.

```rust
// let response = client
//     .place_order(PlaceOrderRequest {
//         contract: ContractRef {
//             security_type: "STK".into(),
//             exchange: "TSE".into(),
//             code: "2330".into(),
//             target_code: None,
//         },
//         stock_order: Some(StockOrder {
//             action: "Buy".into(),
//             price: 580.0,
//             quantity: 1,
//             price_type: "LMT".into(),
//             order_type: "ROD".into(),
//             order_lot: Some("Common".into()),
//             order_cond: Some("Cash".into()),
//         }),
//         futures_order: None,
//     })
//     .await?;
//
// println!("Trade: {:?}", response);
```

## 6. SSE Streaming / SSE 即時串流

**src/stream.rs** -- use `reqwest-eventsource` to connect to SSE endpoints:

```rust
use crate::types::TickData;
use futures_util::StreamExt;
use reqwest_eventsource::{Event, EventSource};

const BASE_URL: &str = "http://localhost:8080";

/// Connect to the tick_stk SSE stream and process events
pub async fn stream_tick_stk() -> Result<(), Box<dyn std::error::Error>> {
    let url = format!("{}/api/v1/stream/data/tick_stk", BASE_URL);
    let mut es = EventSource::get(&url);

    println!("Connected to SSE stream: {}", url);

    while let Some(event) = es.next().await {
        match event {
            Ok(Event::Open) => println!("SSE connection opened"),
            Ok(Event::Message(msg)) => {
                // Event type is "tick_stk", data is JSON
                if msg.event == "tick_stk" {
                    match serde_json::from_str::<TickData>(&msg.data) {
                        Ok(tick) => {
                            println!(
                                "[{} {}] {} close={} vol={}",
                                tick.date, tick.time, tick.code, tick.close, tick.volume
                            );
                        }
                        Err(e) => eprintln!("Parse error: {}", e),
                    }
                }
            }
            Err(e) => {
                eprintln!("SSE error: {}", e);
                break;
            }
        }
    }

    Ok(())
}
```

Available SSE stream endpoints:

| Endpoint | Event Type | Description |
|----------|-----------|-------------|
| `/api/v1/stream/data` | mixed | All subscribed data in one stream |
| `/api/v1/stream/data/tick_stk` | `tick_stk` | Stock tick data |
| `/api/v1/stream/data/bidask_stk` | `bidask_stk` | Stock bid/ask data |
| `/api/v1/stream/data/tick_fop` | `tick_fop` | Futures/options tick data |
| `/api/v1/stream/data/bidask_fop` | `bidask_fop` | Futures/options bid/ask data |
| `/api/v1/stream/data/quote_stk` | `quote_stk` | Stock quote data |
| `/api/v1/stream/data/quote_fop` | `quote_fop` | Futures/options quote data |
| `/api/v1/stream/data/order_event` | `order_event` | Order status events |

Workflow:

1. **Subscribe** -- `POST /api/v1/stream/subscribe` with contract and quote type
2. **Connect** -- `GET /api/v1/stream/data/tick_stk` (or other stream endpoint)
3. **Unsubscribe** -- `POST /api/v1/stream/unsubscribe` when done

For futures continuous-month aliases such as `TXFR1` / `TXFR2`, first call `GET /api/v1/data/contracts/TXFR1?security_type=FUT` and copy the returned `target_code` into `SubscribeRequest`. Regular futures codes do not need `target_code`.

Order events use a separate account subscription in production. Before opening `/api/v1/stream/data/order_event`, call `POST /api/v1/auth/subscribe_trade` once per account; simulation does not require it.

## 7. OpenAPI Client Generation / OpenAPI 客戶端生成

Instead of writing the client by hand, generate a typed Rust client from the server's OpenAPI spec:

除了手動撰寫客戶端，也可以從伺服器的 OpenAPI 規格自動生成型別化的 Rust 客戶端：

```bash
# Make sure the server is running first
openapi-generator generate \
  -i http://localhost:8080/openapi.json \
  -g rust \
  -o shioaji-client
```

This generates a complete Rust crate with typed models and API methods. Add it as a path dependency:

```toml
[dependencies]
shioaji-client = { path = "./shioaji-client" }
```

## 8. Complete Example / 完整範例

**src/main.rs**:

```rust
mod client;
mod stream;
mod types;

use client::ShioajiClient;
use types::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = ShioajiClient::new();

    // 1. List accounts / 列出帳戶
    println!("=== Accounts ===");
    let accounts = client.list_accounts().await?;
    for acc in &accounts {
        println!("  {} (signed: {})", acc.account_id, acc.signed);
    }

    // 2. Get TSMC snapshot / 取得台積電快照
    println!("\n=== Snapshot: 2330 ===");
    let snapshots = client
        .snapshots(vec![ContractRef {
            security_type: "STK".into(),
            exchange: "TSE".into(),
            code: "2330".into(),
            target_code: None,
        }])
        .await?;
    for snap in &snapshots {
        println!("  {} close={} volume={}", snap.code, snap.close, snap.total_volume);
    }

    // 3. Optional order example / 可選下單範例
    // Keep disabled in runnable examples; confirm mode/account/order details first.
    // See ORDERS.md before enabling.
    // let order_resp = client
    //     .place_order(PlaceOrderRequest {
    //         contract: ContractRef {
    //             security_type: "STK".into(),
    //             exchange: "TSE".into(),
    //             code: "2330".into(),
    //             target_code: None,
    //         },
    //         stock_order: Some(StockOrder {
    //             action: "Buy".into(),
    //             price: 580.0,
    //             quantity: 1,
    //             price_type: "LMT".into(),
    //             order_type: "ROD".into(),
    //             order_lot: Some("Common".into()),
    //             order_cond: Some("Cash".into()),
    //         }),
    //         futures_order: None,
    //     })
    //     .await?;
    // println!("  Trade: {:?}", order_resp);

    // 4. Subscribe and stream ticks / 訂閱並串流逐筆成交
    println!("\n=== Subscribing to 2330 ticks ===");
    client
        .subscribe(SubscribeRequest {
            security_type: "STK".into(),
            exchange: "TSE".into(),
            code: "2330".into(),
            target_code: None,
            quote_type: "Tick".into(),
        })
        .await?;

    println!("Streaming tick data (Ctrl+C to stop)...\n");
    stream::stream_tick_stk().await?;

    Ok(())
}
```

Run with:

```bash
cargo run
```

> **Note**: This guide covers consuming the Shioaji HTTP API server from an external Rust application.
>
> **注意**：本指南介紹的是外部 Rust 應用程式如何透過 HTTP API 使用 Shioaji。
