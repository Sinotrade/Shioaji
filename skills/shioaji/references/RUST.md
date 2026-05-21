# Rust HTTP Client Guide / Rust HTTP 客戶端指南

This guide covers consuming the Shioaji HTTP API from Rust using `reqwest` and `reqwest-eventsource`. This is **not** the rshioaji Rust library -- it is for building standalone Rust applications that talk to the Shioaji HTTP server.

本指南介紹如何使用 `reqwest` 和 `reqwest-eventsource` 從 Rust 呼叫 Shioaji HTTP API。這**不是** rshioaji Rust 函式庫，而是用來建立獨立 Rust 應用程式與 Shioaji HTTP 伺服器通訊。

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
uv tool install rshioaji
# or: curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh
export SJ_API_KEY=YOUR_KEY SJ_SEC_KEY=YOUR_SECRET
shioaji server start   # simulation mode by default
```

The server runs at `http://localhost:8080` with all endpoints under `/api/v1/`.

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
    pub security_type: String,   // "STK" or "FUT" or "OPT"
    pub exchange: String,        // "TSE", "OTC", "TAIFEX"
    pub code: String,            // e.g. "2330"
}

/// POST /api/v1/data/snapshots request body
#[derive(Debug, Serialize)]
pub struct SnapshotsRequest {
    pub contracts: Vec<ContractRef>,
}

/// Snapshot response item
#[derive(Debug, Deserialize)]
pub struct Snapshot {
    pub code: String,
    pub close: f64,
    pub volume: i64,
    pub total_volume: i64,
    pub ts: i64,
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
    pub order: OrderSpec,
}

#[derive(Debug, Serialize)]
pub struct OrderSpec {
    pub action: String,           // "Buy" or "Sell"
    pub price: f64,
    pub quantity: i32,
    pub price_type: String,       // "LMT", "MKT"
    pub order_type: String,       // "ROD", "IOC", "FOK"
}

/// Place order response
#[derive(Debug, Deserialize)]
pub struct OrderResponse {
    pub order_id: String,
    pub status: String,
}

/// SSE subscribe request
#[derive(Debug, Serialize)]
pub struct SubscribeRequest {
    pub security_type: String,
    pub exchange: String,
    pub code: String,
    pub quote_type: String,       // "Tick", "BidAsk", "Quote"
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
    pub vol_sum: u64,
    pub tick_type: u32,
    #[serde(with = "rust_decimal::serde::str")]
    pub diff_price: rust_decimal::Decimal,
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
    ) -> Result<OrderResponse, reqwest::Error> {
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
    ) -> Result<reqwest::Response, reqwest::Error> {
        self.client
            .post(format!("{}/api/v1/stream/subscribe", self.base_url))
            .json(&request)
            .send()
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
    }])
    .await?;

for snap in &snapshots {
    println!("{}: close={}, volume={}", snap.code, snap.close, snap.total_volume);
}
```

### Place Order / 下單

```rust
let response = client
    .place_order(PlaceOrderRequest {
        contract: ContractRef {
            security_type: "STK".into(),
            exchange: "TSE".into(),
            code: "2330".into(),
        },
        order: OrderSpec {
            action: "Buy".into(),
            price: 580.0,
            quantity: 1,
            price_type: "LMT".into(),
            order_type: "ROD".into(),
        },
    })
    .await?;

println!("Order ID: {}, Status: {}", response.order_id, response.status);
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
                                "[{}] {} close={} vol={}",
                                tick.ts, tick.code, tick.close, tick.volume
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
        }])
        .await?;
    for snap in &snapshots {
        println!("  {} close={} volume={}", snap.code, snap.close, snap.total_volume);
    }

    // 3. Place a limit order / 下限價單
    println!("\n=== Place Order ===");
    let order_resp = client
        .place_order(PlaceOrderRequest {
            contract: ContractRef {
                security_type: "STK".into(),
                exchange: "TSE".into(),
                code: "2330".into(),
            },
            order: OrderSpec {
                action: "Buy".into(),
                price: 580.0,
                quantity: 1,
                price_type: "LMT".into(),
                order_type: "ROD".into(),
            },
        })
        .await?;
    println!("  Order: {} status={}", order_resp.order_id, order_resp.status);

    // 4. Subscribe and stream ticks / 訂閱並串流逐筆成交
    println!("\n=== Subscribing to 2330 ticks ===");
    client
        .subscribe(SubscribeRequest {
            security_type: "STK".into(),
            exchange: "TSE".into(),
            code: "2330".into(),
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

> **Note**: This guide covers consuming the HTTP API server. If you are building within the rshioaji Rust codebase itself, use the Rust library directly instead of HTTP.
>
> **注意**：本指南介紹的是透過 HTTP API 使用 Shioaji。若您在 rshioaji Rust 專案內開發，請直接使用 Rust 函式庫，無需透過 HTTP。
