# JavaScript / TypeScript -- Shioaji HTTP API 完整指南 | Complete Guide

> Shioaji HTTP API Server 讓 JavaScript/TypeScript 開發者可以使用永豐金證券的交易功能。
> The Shioaji HTTP API Server lets JavaScript/TypeScript developers access SinoPac's trading capabilities.

---

## 目錄 | Table of Contents

1. [伺服器啟動 | Server Startup](#1-伺服器啟動--server-startup)
2. [專案設定 | Project Setup](#2-專案設定--project-setup)
3. [專案結構 | Project Layout](#3-專案結構--project-layout)
4. [API 客戶端模組 | API Client Module](#4-api-客戶端模組--api-client-module)
5. [HTTP 範例 | HTTP Examples](#5-http-範例--http-examples)
   - [查詢帳戶 | List Accounts](#51-查詢帳戶--list-accounts)
   - [快照報價 | Snapshots](#52-快照報價--snapshots)
   - [下單 | Place Order](#53-下單--place-order)
6. [SSE 即時串流 | SSE Streaming](#6-sse-即時串流--sse-streaming)
   - [訂閱 | Subscribe](#61-訂閱--subscribe)
   - [接收資料 | Receive Data](#62-接收資料--receive-data)
   - [可用串流端點 | Available Stream Endpoints](#63-可用串流端點--available-stream-endpoints)
   - [斷線重連 | Reconnection Handling](#64-斷線重連--reconnection-handling)
7. [OpenAPI 客戶端產生 | OpenAPI Client Generation](#7-openapi-客戶端產生--openapi-client-generation)
8. [完整範例 | Complete Runnable Example](#8-完整範例--complete-runnable-example)

---

## 1. 伺服器啟動 | Server Startup

```bash
# 安裝 rshioaji | Install rshioaji
uv tool install rshioaji
# or: curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh

# 啟動伺服器（預設為模擬模式）| Start server (simulation mode by default)
shioaji server start
```

伺服器預設在 `http://localhost:8080` 啟動。
The server starts at `http://localhost:8080` by default.

- **Localhost 模式**: 不需要認證 | No authentication required
- **公開綁定模式**: 需要 `Authorization: Bearer SJ_API_KEY:SJ_SEC_KEY` | Auth required when binding to non-localhost

---

## 2. 專案設定 | Project Setup

```bash
mkdir my-trading-app && cd my-trading-app
npm init -y

# 安裝依賴 | Install dependencies
npm install typescript @types/node eventsource
npm install -D tsx

# 初始化 TypeScript
npx tsc --init
```

**tsconfig.json** 建議設定 | Recommended configuration:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src"]
}
```

---

## 3. 專案結構 | Project Layout

```
my-trading-app/
├── src/
│   ├── client/shioaji-client.ts  # API 客戶端 | API client
│   ├── streaming/sse.ts          # SSE 連線 | SSE connection
│   ├── strategies/               # 交易策略 | User trading logic
│   │   └── example-strategy.ts
│   └── index.ts                  # 進入點 | Entry point
├── package.json
└── tsconfig.json
```

---

## 4. API 客戶端模組 | API Client Module

`src/client/shioaji-client.ts`:

```typescript
// ============================================================================
// 型別定義 | Type Definitions
// ============================================================================

/** 合約請求 | Contract request */
export interface ContractRequest {
  security_type: "STK" | "FUT" | "OPT" | "IND";
  exchange: "TSE" | "OTC" | "TAIFEX";
  code: string;
  target_code?: string;
}

/** 帳戶 | Account */
export interface Account {
  account_type: string;
  person_id: string;
  broker_id: string;
  account_id: string;
  signed: boolean;
}

/** 快照 | Snapshot */
export interface Snapshot {
  ts: number;
  code: string;
  exchange: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  total_volume: number;
  amount: number;
  total_amount: number;
  buy_price: number;
  buy_volume: number;
  sell_price: number;
  sell_volume: number;
  change_price: number;
  change_type: string;
}

/** 股票下單 | Stock order */
export interface StockOrder {
  action: "Buy" | "Sell";
  price: number;
  quantity: number;
  price_type: "LMT" | "MKT";
  order_type: "ROD" | "IOC" | "FOK";
  order_lot?: "Common" | "Odd" | "IntradayOdd";
  order_cond?: "Cash" | "MarginTrading" | "ShortSelling";
  daytrade_short?: boolean;
  custom_field?: string;
}

/** 期貨下單 | Futures order */
export interface FuturesOrder {
  action: "Buy" | "Sell";
  price: number;
  quantity: number;
  price_type: "LMT" | "MKT" | "MKP";
  order_type: "ROD" | "IOC" | "FOK";
  octype?: "Auto" | "New" | "Cover" | "DayTrade";
  custom_field?: string;
}

/** 下單請求 | Place order request */
export interface PlaceOrderRequest {
  contract: ContractRequest;
  stock_order?: StockOrder;
  futures_order?: FuturesOrder;
}

/** 交易結果 | Trade result */
export interface Trade {
  id: string;
  seqno: string;
  ordno: string;
  action: string;
  price: number;
  quantity: number;
  order_type: string;
  price_type: string;
}

/** 訂閱請求 | Subscription request */
export interface SubscriptionRequest {
  security_type: "STK" | "FUT" | "OPT" | "IND";
  exchange: "TSE" | "OTC" | "TAIFEX";
  code: string;
  target_code?: string;
  quote_type: "Tick" | "BidAsk" | "Quote";
  intraday_odd?: boolean;
}

/** 訂閱回應 | Subscription response */
export interface SubscriptionResponse {
  success: boolean;
  message: string;
  subscription?: SubscriptionRequest;
}

// ============================================================================
// API 客戶端 | API Client
// ============================================================================

export class ShioajiClient {
  private baseUrl: string;
  private headers: Record<string, string>;

  /**
   * @param baseUrl - API 伺服器位址 | API server URL (default: http://localhost:8080)
   * @param apiKey - SJ_API_KEY（非 localhost 時需要）| Required for non-localhost
   * @param secretKey - SJ_SEC_KEY（非 localhost 時需要）| Required for non-localhost
   */
  constructor(
    baseUrl: string = "http://localhost:8080",
    apiKey?: string,
    secretKey?: string
  ) {
    this.baseUrl = baseUrl;
    this.headers = { "Content-Type": "application/json" };

    // 非 localhost 需要認證 | Auth required for non-localhost
    if (apiKey && secretKey) {
      this.headers["Authorization"] = `Bearer ${apiKey}:${secretKey}`;
    }
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<T> {
    const url = `${this.baseUrl}/api/v1${path}`;
    const res = await fetch(url, {
      method,
      headers: this.headers,
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!res.ok) {
      const error = await res.json().catch(() => ({ message: res.statusText }));
      throw new Error(
        `API Error ${res.status}: ${error.message || res.statusText}`
      );
    }

    return res.json() as Promise<T>;
  }

  // ------------------------------------------------------------------
  // 認證 | Auth
  // ------------------------------------------------------------------

  /** 查詢帳戶 | List accounts */
  async listAccounts(): Promise<Account[]> {
    return this.request<Account[]>("GET", "/auth/accounts");
  }

  // ------------------------------------------------------------------
  // 行情資料 | Market Data
  // ------------------------------------------------------------------

  /** 取得快照 | Get snapshots */
  async snapshots(contracts: ContractRequest[]): Promise<Snapshot[]> {
    return this.request<Snapshot[]>("POST", "/data/snapshots", { contracts });
  }

  // ------------------------------------------------------------------
  // 下單 | Orders
  // ------------------------------------------------------------------

  /** 下單 | Place order */
  async placeOrder(req: PlaceOrderRequest): Promise<Trade> {
    return this.request<Trade>("POST", "/order/place_order", req);
  }

  /** 取消委託 | Cancel order */
  async cancelOrder(tradeId: string): Promise<Trade> {
    return this.request<Trade>("POST", "/order/cancel_order", {
      trade_id: tradeId,
    });
  }

  /** 改價 | Update price */
  async updatePrice(tradeId: string, price: number): Promise<Trade> {
    return this.request<Trade>("POST", "/order/update_price", {
      trade_id: tradeId,
      price,
    });
  }

  /** 改量 | Update quantity */
  async updateQty(tradeId: string, quantity: number): Promise<Trade> {
    return this.request<Trade>("POST", "/order/update_qty", {
      trade_id: tradeId,
      quantity,
    });
  }

  // ------------------------------------------------------------------
  // 串流 | Streaming
  // ------------------------------------------------------------------

  /** 訂閱行情 | Subscribe to market data */
  async subscribe(req: SubscriptionRequest): Promise<SubscriptionResponse> {
    return this.request<SubscriptionResponse>(
      "POST",
      "/stream/subscribe",
      req
    );
  }

  /** 取消訂閱 | Unsubscribe */
  async unsubscribe(req: SubscriptionRequest): Promise<SubscriptionResponse> {
    return this.request<SubscriptionResponse>(
      "POST",
      "/stream/unsubscribe",
      req
    );
  }
}
```

---

## 5. HTTP 範例 | HTTP Examples

### 5.1 查詢帳戶 | List Accounts

```typescript
const client = new ShioajiClient();
const accounts = await client.listAccounts();
console.log("帳戶列表 | Accounts:", accounts);
```

等同 raw fetch | Equivalent raw fetch:

```typescript
const resp = await fetch("http://localhost:8080/api/v1/auth/accounts");
const accounts = await resp.json();
```

### 5.2 快照報價 | Snapshots

```typescript
const snapshots = await client.snapshots([
  { security_type: "STK", exchange: "TSE", code: "2330" },
  { security_type: "STK", exchange: "TSE", code: "2317" },
]);
console.log("快照 | Snapshots:", snapshots);
```

等同 raw fetch | Equivalent raw fetch:

```typescript
const resp = await fetch("http://localhost:8080/api/v1/data/snapshots", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    contracts: [{ security_type: "STK", exchange: "TSE", code: "2330" }],
  }),
});
const snapshots = await resp.json();
```

### 5.3 下單 | Place Order

**股票限價買 | Stock limit buy:**

```typescript
const trade = await client.placeOrder({
  contract: { security_type: "STK", exchange: "TSE", code: "2330" },
  stock_order: {
    action: "Buy",
    price: 600.0,
    quantity: 1,
    price_type: "LMT",
    order_type: "ROD",
  },
});
console.log("成交回報 | Trade:", trade);
```

**期貨市價賣 | Futures market sell:**

```typescript
const trade = await client.placeOrder({
  contract: { security_type: "FUT", exchange: "TAIFEX", code: "TXFC5" },
  futures_order: {
    action: "Sell",
    price: 0,
    quantity: 1,
    price_type: "MKT",
    order_type: "IOC",
  },
});
```

---

## 6. SSE 即時串流 | SSE Streaming

Shioaji 使用 Server-Sent Events (SSE) 推送即時行情。伺服器每 30 秒發送 heartbeat 保持連線。
Shioaji uses Server-Sent Events (SSE) for real-time market data. The server sends a heartbeat every 30 seconds to keep connections alive.

### 6.1 訂閱 | Subscribe

先透過 HTTP 訂閱，再開啟 SSE 連線。
Subscribe via HTTP first, then open the SSE connection.

```typescript
// 步驟 1: 訂閱 | Step 1: Subscribe
await client.subscribe({
  security_type: "STK",
  exchange: "TSE",
  code: "2330",
  quote_type: "Tick",
});
```

### 6.2 接收資料 | Receive Data

**瀏覽器 | Browser:**

```typescript
const es = new EventSource("http://localhost:8080/api/v1/stream/data/tick_stk");

es.addEventListener("tick_stk", (e) => {
  const tick = JSON.parse(e.data);
  console.log("Tick:", tick);
});

es.addEventListener("heartbeat", (e) => {
  const hb = JSON.parse(e.data);
  console.log("Heartbeat:", hb.timestamp);
});

es.addEventListener("error", (e) => {
  console.error("SSE error:", e);
});
```

**Node.js（需要 eventsource 套件）| Node.js (requires eventsource package):**

```typescript
import EventSource from "eventsource";

// 非 localhost 帶認證 | With auth for non-localhost
const url = "http://localhost:8080/api/v1/stream/data/tick_stk";
const es = new EventSource(url, {
  headers: {
    Authorization: `Bearer ${apiKey}:${secretKey}`,
  },
});

es.addEventListener("tick_stk", (e: MessageEvent) => {
  const tick = JSON.parse(e.data);
  console.log(`${tick.code} @ ${tick.close} x ${tick.volume}`);
});
```

### 6.3 可用串流端點 | Available Stream Endpoints

| 端點 Path | 事件名稱 Event Name | 說明 Description |
|---|---|---|
| `/api/v1/stream/data` | `tick_stk`, `bidask_stk`, `tick_fop`, `bidask_fop`, `quote_stk`, `quote_fop`, `order_event` | 所有資料合併串流 All data merged |
| `/api/v1/stream/data/tick_stk` | `tick_stk` | 股票逐筆成交 Stock ticks |
| `/api/v1/stream/data/bidask_stk` | `bidask_stk` | 股票五檔報價 Stock bid/ask |
| `/api/v1/stream/data/tick_fop` | `tick_fop` | 期貨選擇權逐筆成交 Futures/Options ticks |
| `/api/v1/stream/data/bidask_fop` | `bidask_fop` | 期貨選擇權五檔報價 Futures/Options bid/ask |
| `/api/v1/stream/data/quote_stk` | `quote_stk` | 股票整合報價 Stock quotes |
| `/api/v1/stream/data/quote_fop` | `quote_fop` | 期貨選擇權整合報價 Futures/Options quotes |
| `/api/v1/stream/data/order_event` | `order_event` | 委託/成交回報 Order events |

所有串流端點都會附帶 `heartbeat` 事件（每 30 秒）。
All stream endpoints include `heartbeat` events (every 30 seconds).

### 6.4 斷線重連 | Reconnection Handling

`EventSource` 有內建自動重連，但你可以自訂邏輯：
`EventSource` has built-in auto-reconnect, but you can customize:

```typescript
function createReconnectingStream(
  url: string,
  eventName: string,
  onData: (data: unknown) => void,
  maxRetries = 10
) {
  let retries = 0;
  let es: EventSource;

  function connect() {
    es = new EventSource(url);

    es.addEventListener(eventName, (e: MessageEvent) => {
      retries = 0; // 成功收到資料重置計數 | Reset on successful data
      onData(JSON.parse(e.data));
    });

    es.addEventListener("heartbeat", () => {
      retries = 0;
    });

    es.onerror = () => {
      es.close();
      if (retries < maxRetries) {
        const delay = Math.min(1000 * 2 ** retries, 30000);
        console.log(`Reconnecting in ${delay}ms (attempt ${retries + 1})`);
        setTimeout(connect, delay);
        retries++;
      } else {
        console.error("Max retries reached, giving up");
      }
    };
  }

  connect();
  return () => es.close(); // 回傳清理函式 | Return cleanup function
}

// 使用 | Usage
const cleanup = createReconnectingStream(
  "http://localhost:8080/api/v1/stream/data/tick_stk",
  "tick_stk",
  (tick) => console.log("Tick:", tick)
);

// 結束時呼叫 | Call when done
// cleanup();
```

---

## 7. OpenAPI 客戶端產生 | OpenAPI Client Generation

Shioaji 提供 OpenAPI 規格，可自動產生型別定義：
Shioaji provides an OpenAPI spec for auto-generating type definitions:

```bash
# 產生 TypeScript 型別 | Generate TypeScript types
npx openapi-typescript http://localhost:8080/openapi.json -o src/shioaji.d.ts

# 使用產生的型別 | Use generated types
```

```typescript
import type { paths } from "./shioaji.d.ts";

type SnapshotResponse =
  paths["/api/v1/data/snapshots"]["post"]["responses"]["200"]["content"]["application/json"];
```

或使用 `openapi-fetch` 搭配產生的型別建立完全型別安全的客戶端：
Or use `openapi-fetch` with generated types for a fully type-safe client:

```bash
npm install openapi-fetch
```

```typescript
import createClient from "openapi-fetch";
import type { paths } from "./shioaji.d.ts";

const client = createClient<paths>({
  baseUrl: "http://localhost:8080/api/v1",
});

const { data } = await client.POST("/data/snapshots", {
  body: {
    contracts: [{ security_type: "STK", exchange: "TSE", code: "2330" }],
  },
});
```

---

## 8. 完整範例 | Complete Runnable Example

`src/index.ts` -- 啟動後即可執行的完整程式 | Ready-to-run complete program:

```typescript
import { ShioajiClient } from "./client/shioaji-client";
import EventSource from "eventsource";

async function main() {
  // ================================================================
  // 初始化 | Initialize
  // ================================================================
  const client = new ShioajiClient("http://localhost:8080");

  // ================================================================
  // 1. 查詢帳戶 | List accounts
  // ================================================================
  const accounts = await client.listAccounts();
  console.log("=== 帳戶 | Accounts ===");
  console.log(JSON.stringify(accounts, null, 2));

  // ================================================================
  // 2. 取得快照 | Get snapshots
  // ================================================================
  const snapshots = await client.snapshots([
    { security_type: "STK", exchange: "TSE", code: "2330" },
  ]);
  console.log("\n=== 快照 | Snapshots ===");
  for (const snap of snapshots) {
    console.log(`${snap.code}: ${snap.close} (${snap.change_price})`);
  }

  // ================================================================
  // 3. 訂閱即時行情 | Subscribe to real-time data
  // ================================================================
  const subResult = await client.subscribe({
    security_type: "STK",
    exchange: "TSE",
    code: "2330",
    quote_type: "Tick",
  });
  console.log("\n=== 訂閱結果 | Subscription ===");
  console.log(subResult.message);

  // ================================================================
  // 4. 接收 SSE 串流 | Receive SSE stream
  // ================================================================
  const es = new EventSource(
    "http://localhost:8080/api/v1/stream/data/tick_stk"
  );

  es.addEventListener("tick_stk", (e: MessageEvent) => {
    const tick = JSON.parse(e.data);
    console.log(
      `[TICK] ${tick.code} price=${tick.close} vol=${tick.volume} ts=${tick.ts}`
    );
  });

  es.addEventListener("heartbeat", (e: MessageEvent) => {
    const hb = JSON.parse(e.data);
    console.log(`[HEARTBEAT] ${hb.timestamp}`);
  });

  es.onerror = () => {
    console.error("[SSE] Connection error, will auto-reconnect...");
  };

  // ================================================================
  // 5. 下單範例（取消註解以執行）| Order example (uncomment to run)
  // ================================================================
  // const trade = await client.placeOrder({
  //   contract: { security_type: "STK", exchange: "TSE", code: "2330" },
  //   stock_order: {
  //     action: "Buy",
  //     price: 600.0,
  //     quantity: 1,
  //     price_type: "LMT",
  //     order_type: "ROD",
  //   },
  // });
  // console.log("Trade:", trade);

  // 按 Ctrl+C 結束 | Press Ctrl+C to stop
  console.log("\n串流中... Ctrl+C 結束 | Streaming... Ctrl+C to stop");
}

main().catch(console.error);
```

**執行 | Run:**

```bash
npx tsx src/index.ts
```
