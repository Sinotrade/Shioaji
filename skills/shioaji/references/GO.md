# Go -- Shioaji HTTP API 完整指南 | Complete Guide

> Shioaji HTTP API Server 讓 Go 開發者可以使用永豐金證券的交易功能。
> The Shioaji HTTP API Server lets Go developers access SinoPac's trading capabilities.

---

## 目錄 | Table of Contents

1. [伺服器啟動 | Server Startup](#1-伺服器啟動--server-startup)
2. [專案設定 | Project Setup](#2-專案設定--project-setup)
3. [專案結構 | Project Layout](#3-專案結構--project-layout)
4. [API 客戶端套件 | API Client Package](#4-api-客戶端套件--api-client-package)
   - [型別定義 | Type Definitions](#41-型別定義--type-definitions)
   - [客戶端 | Client](#42-客戶端--client)
   - [SSE 串流 | SSE Stream](#43-sse-串流--sse-stream)
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
go mod init my-trading-app
```

不需要額外依賴。Go 標準函式庫已包含 HTTP 客戶端和 JSON 處理。
No external dependencies needed. Go's standard library includes HTTP client and JSON handling.

---

## 3. 專案結構 | Project Layout

```
my-trading-app/
├── cmd/app/main.go               # 進入點 | Entry point
├── pkg/shioaji/
│   ├── client.go                  # API 客戶端 | API client
│   ├── types.go                   # 型別定義 | Type definitions
│   └── stream.go                  # SSE 串流 | SSE streaming
├── internal/strategies/           # 交易策略 | User trading logic
│   └── example.go
└── go.mod
```

---

## 4. API 客戶端套件 | API Client Package

### 4.1 型別定義 | Type Definitions

`pkg/shioaji/types.go`:

```go
package shioaji

// ============================================================================
// 合約 | Contract
// ============================================================================

// ContractRequest 合約請求
type ContractRequest struct {
	SecurityType string  `json:"security_type"` // STK, FUT, OPT, IND
	Exchange     string  `json:"exchange"`       // TSE, OTC, TAIFEX
	Code         string  `json:"code"`
	TargetCode   *string `json:"target_code,omitempty"`
}

// ============================================================================
// 帳戶 | Account
// ============================================================================

// Account 帳戶
type Account struct {
	AccountType string `json:"account_type"`
	PersonID    string `json:"person_id"`
	BrokerID    string `json:"broker_id"`
	AccountID   string `json:"account_id"`
	Signed      bool   `json:"signed"`
}

// ============================================================================
// 行情 | Market Data
// ============================================================================

// SnapshotRequest 快照請求
type SnapshotRequest struct {
	Contracts []ContractRequest `json:"contracts"`
}

// Snapshot 快照
type Snapshot struct {
	Ts          int64   `json:"ts"`
	Code        string  `json:"code"`
	Exchange    string  `json:"exchange"`
	Open        float64 `json:"open"`
	High        float64 `json:"high"`
	Low         float64 `json:"low"`
	Close       float64 `json:"close"`
	Volume      int64   `json:"volume"`
	TotalVolume int64   `json:"total_volume"`
	Amount      float64 `json:"amount"`
	TotalAmount float64 `json:"total_amount"`
	BuyPrice    float64 `json:"buy_price"`
	BuyVolume   int64   `json:"buy_volume"`
	SellPrice   float64 `json:"sell_price"`
	SellVolume  int64   `json:"sell_volume"`
	ChangePrice float64 `json:"change_price"`
	ChangeType  string  `json:"change_type"`
}

// ============================================================================
// 下單 | Order
// ============================================================================

// StockOrder 股票委託
type StockOrder struct {
	Action        string  `json:"action"`                    // Buy, Sell
	Price         float64 `json:"price"`
	Quantity      int     `json:"quantity"`
	PriceType     string  `json:"price_type"`                // LMT, MKT
	OrderType     string  `json:"order_type"`                // ROD, IOC, FOK
	OrderLot      *string `json:"order_lot,omitempty"`       // Common, Odd, IntradayOdd
	OrderCond     *string `json:"order_cond,omitempty"`      // Cash, MarginTrading, ShortSelling
	DaytradeShort *bool   `json:"daytrade_short,omitempty"`
	CustomField   *string `json:"custom_field,omitempty"`
}

// FuturesOrder 期貨委託
type FuturesOrder struct {
	Action      string  `json:"action"`               // Buy, Sell
	Price       float64 `json:"price"`
	Quantity    int     `json:"quantity"`
	PriceType   string  `json:"price_type"`            // LMT, MKT, MKP
	OrderType   string  `json:"order_type"`            // ROD, IOC, FOK
	OCType      *string `json:"octype,omitempty"`      // Auto, New, Cover, DayTrade
	CustomField *string `json:"custom_field,omitempty"`
}

// PlaceOrderRequest 下單請求
type PlaceOrderRequest struct {
	Contract     ContractRequest `json:"contract"`
	StockOrder   *StockOrder     `json:"stock_order,omitempty"`
	FuturesOrder *FuturesOrder   `json:"futures_order,omitempty"`
}

// Trade 交易結果
type Trade struct {
	ID        string  `json:"id"`
	SeqNo     string  `json:"seqno"`
	OrdNo     string  `json:"ordno"`
	Action    string  `json:"action"`
	Price     float64 `json:"price"`
	Quantity  int     `json:"quantity"`
	OrderType string  `json:"order_type"`
	PriceType string  `json:"price_type"`
}

// CancelOrderRequest 取消委託
type CancelOrderRequest struct {
	TradeID string `json:"trade_id"`
}

// UpdatePriceRequest 改價
type UpdatePriceRequest struct {
	TradeID string  `json:"trade_id"`
	Price   float64 `json:"price"`
}

// UpdateQtyRequest 改量
type UpdateQtyRequest struct {
	TradeID  string `json:"trade_id"`
	Quantity int    `json:"quantity"`
}

// ============================================================================
// 串流 | Stream
// ============================================================================

// SubscriptionRequest 訂閱請求
type SubscriptionRequest struct {
	SecurityType string `json:"security_type"` // STK, FUT, OPT, IND
	Exchange     string `json:"exchange"`      // TSE, OTC, TAIFEX
	Code         string `json:"code"`
	TargetCode   string `json:"target_code,omitempty"`
	QuoteType    string `json:"quote_type"`    // Tick, BidAsk, Quote
	IntradayOdd  bool   `json:"intraday_odd,omitempty"`
}

// SubscriptionResponse 訂閱回應
type SubscriptionResponse struct {
	Success      bool                  `json:"success"`
	Message      string                `json:"message"`
	Subscription *SubscriptionRequest  `json:"subscription,omitempty"`
}

// SSEEvent SSE 事件
type SSEEvent struct {
	Event string // 事件名稱 | Event name (e.g. "tick_stk", "heartbeat")
	Data  string // JSON 資料 | JSON data
}

// ErrorResponse API 錯誤
type ErrorResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}
```

### 4.2 客戶端 | Client

`pkg/shioaji/client.go`:

```go
package shioaji

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// Client Shioaji API 客戶端
type Client struct {
	BaseURL    string
	HTTPClient *http.Client
	apiKey     string
	secretKey  string
}

// NewClient 建立客戶端 | Create client
// apiKey 和 secretKey 在 localhost 模式可留空
// apiKey and secretKey can be empty for localhost mode
func NewClient(baseURL string, apiKey, secretKey string) *Client {
	return &Client{
		BaseURL:    baseURL,
		HTTPClient: &http.Client{},
		apiKey:     apiKey,
		secretKey:  secretKey,
	}
}

func (c *Client) doRequest(method, path string, body any, result any) error {
	var bodyReader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("marshal request: %w", err)
		}
		bodyReader = bytes.NewReader(data)
	}

	req, err := http.NewRequest(method, c.BaseURL+"/api/v1"+path, bodyReader)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	// 非 localhost 需要認證 | Auth required for non-localhost
	if c.apiKey != "" && c.secretKey != "" {
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s:%s", c.apiKey, c.secretKey))
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API error %d: %s", resp.StatusCode, string(respBody))
	}

	if result != nil {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("decode response: %w", err)
		}
	}
	return nil
}

// ============================================================================
// 認證 | Auth
// ============================================================================

// ListAccounts 查詢帳戶
func (c *Client) ListAccounts() ([]Account, error) {
	var accounts []Account
	err := c.doRequest("GET", "/auth/accounts", nil, &accounts)
	return accounts, err
}

// ============================================================================
// 行情資料 | Market Data
// ============================================================================

// Snapshots 取得快照
func (c *Client) Snapshots(contracts []ContractRequest) ([]Snapshot, error) {
	var snapshots []Snapshot
	err := c.doRequest("POST", "/data/snapshots", SnapshotRequest{Contracts: contracts}, &snapshots)
	return snapshots, err
}

// ============================================================================
// 下單 | Orders
// ============================================================================

// PlaceOrder 下單
func (c *Client) PlaceOrder(req PlaceOrderRequest) (*Trade, error) {
	var trade Trade
	err := c.doRequest("POST", "/order/place_order", req, &trade)
	return &trade, err
}

// CancelOrder 取消委託
func (c *Client) CancelOrder(tradeID string) (*Trade, error) {
	var trade Trade
	err := c.doRequest("POST", "/order/cancel_order", CancelOrderRequest{TradeID: tradeID}, &trade)
	return &trade, err
}

// UpdatePrice 改價
func (c *Client) UpdatePrice(tradeID string, price float64) (*Trade, error) {
	var trade Trade
	err := c.doRequest("POST", "/order/update_price", UpdatePriceRequest{TradeID: tradeID, Price: price}, &trade)
	return &trade, err
}

// UpdateQty 改量
func (c *Client) UpdateQty(tradeID string, quantity int) (*Trade, error) {
	var trade Trade
	err := c.doRequest("POST", "/order/update_qty", UpdateQtyRequest{TradeID: tradeID, Quantity: quantity}, &trade)
	return &trade, err
}

// ============================================================================
// 串流 | Streaming
// ============================================================================

// Subscribe 訂閱行情
func (c *Client) Subscribe(req SubscriptionRequest) (*SubscriptionResponse, error) {
	var resp SubscriptionResponse
	err := c.doRequest("POST", "/stream/subscribe", req, &resp)
	return &resp, err
}

// Unsubscribe 取消訂閱
func (c *Client) Unsubscribe(req SubscriptionRequest) (*SubscriptionResponse, error) {
	var resp SubscriptionResponse
	err := c.doRequest("POST", "/stream/unsubscribe", req, &resp)
	return &resp, err
}
```

### 4.3 SSE 串流 | SSE Stream

`pkg/shioaji/stream.go`:

```go
package shioaji

import (
	"bufio"
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// SSEHandler SSE 事件處理回呼 | SSE event handler callback
type SSEHandler func(event SSEEvent)

// StreamSSE 連線到 SSE 串流端點 | Connect to an SSE stream endpoint
// path 範例 | path example: "/stream/data/tick_stk"
// 此函式會阻塞直到 context 取消或連線中斷
// This function blocks until the context is cancelled or connection drops
func (c *Client) StreamSSE(ctx context.Context, path string, handler SSEHandler) error {
	url := c.BaseURL + "/api/v1" + path

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return fmt.Errorf("create SSE request: %w", err)
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Cache-Control", "no-cache")

	if c.apiKey != "" && c.secretKey != "" {
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s:%s", c.apiKey, c.secretKey))
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("SSE connect: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("SSE connect failed: status %d", resp.StatusCode)
	}

	scanner := bufio.NewScanner(resp.Body)
	var currentEvent string

	for scanner.Scan() {
		line := scanner.Text()

		if strings.HasPrefix(line, "event:") {
			currentEvent = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
		} else if strings.HasPrefix(line, "data:") {
			data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
			handler(SSEEvent{
				Event: currentEvent,
				Data:  data,
			})
			currentEvent = ""
		}
		// 空行代表事件結束 | Empty line means end of event
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("SSE read: %w", err)
	}
	return nil
}

// StreamSSEWithReconnect 帶自動重連的 SSE 串流
// SSE stream with automatic reconnection
func (c *Client) StreamSSEWithReconnect(
	ctx context.Context,
	path string,
	handler SSEHandler,
	maxRetries int,
) error {
	retries := 0
	for {
		err := c.StreamSSE(ctx, path, handler)
		if ctx.Err() != nil {
			return ctx.Err() // context 已取消 | context cancelled
		}

		retries++
		if maxRetries > 0 && retries > maxRetries {
			return fmt.Errorf("max retries (%d) reached, last error: %w", maxRetries, err)
		}

		// 指數退避 | Exponential backoff
		delay := time.Duration(1<<uint(retries-1)) * time.Second
		if delay > 30*time.Second {
			delay = 30 * time.Second
		}
		fmt.Printf("SSE disconnected, reconnecting in %v (attempt %d)...\n", delay, retries)

		select {
		case <-time.After(delay):
			continue
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}
```

---

## 5. HTTP 範例 | HTTP Examples

### 5.1 查詢帳戶 | List Accounts

```go
client := shioaji.NewClient("http://localhost:8080", "", "")
accounts, err := client.ListAccounts()
if err != nil {
    log.Fatal(err)
}
for _, acc := range accounts {
    fmt.Printf("帳戶 | Account: %s-%s (%s)\n", acc.BrokerID, acc.AccountID, acc.AccountType)
}
```

等同 raw HTTP | Equivalent raw HTTP:

```go
resp, err := http.Get("http://localhost:8080/api/v1/auth/accounts")
if err != nil {
    log.Fatal(err)
}
defer resp.Body.Close()

var accounts []shioaji.Account
json.NewDecoder(resp.Body).Decode(&accounts)
```

### 5.2 快照報價 | Snapshots

```go
snapshots, err := client.Snapshots([]shioaji.ContractRequest{
    {SecurityType: "STK", Exchange: "TSE", Code: "2330"},
    {SecurityType: "STK", Exchange: "TSE", Code: "2317"},
})
if err != nil {
    log.Fatal(err)
}
for _, snap := range snapshots {
    fmt.Printf("%s: %.2f (%.2f)\n", snap.Code, snap.Close, snap.ChangePrice)
}
```

等同 raw HTTP | Equivalent raw HTTP:

```go
body, _ := json.Marshal(shioaji.SnapshotRequest{
    Contracts: []shioaji.ContractRequest{
        {SecurityType: "STK", Exchange: "TSE", Code: "2330"},
    },
})
resp, _ := http.Post(
    "http://localhost:8080/api/v1/data/snapshots",
    "application/json",
    bytes.NewReader(body),
)
defer resp.Body.Close()

var snapshots []shioaji.Snapshot
json.NewDecoder(resp.Body).Decode(&snapshots)
```

### 5.3 下單 | Place Order

**股票限價買 | Stock limit buy:**

```go
trade, err := client.PlaceOrder(shioaji.PlaceOrderRequest{
    Contract: shioaji.ContractRequest{
        SecurityType: "STK",
        Exchange:     "TSE",
        Code:         "2330",
    },
    StockOrder: &shioaji.StockOrder{
        Action:    "Buy",
        Price:     600.0,
        Quantity:  1,
        PriceType: "LMT",
        OrderType: "ROD",
    },
})
if err != nil {
    log.Fatal(err)
}
fmt.Printf("成交 | Trade: %+v\n", trade)
```

**期貨市價賣 | Futures market sell:**

```go
trade, err := client.PlaceOrder(shioaji.PlaceOrderRequest{
    Contract: shioaji.ContractRequest{
        SecurityType: "FUT",
        Exchange:     "TAIFEX",
        Code:         "TXFC5",
    },
    FuturesOrder: &shioaji.FuturesOrder{
        Action:    "Sell",
        Price:     0,
        Quantity:  1,
        PriceType: "MKT",
        OrderType: "IOC",
    },
})
```

---

## 6. SSE 即時串流 | SSE Streaming

Shioaji 使用 Server-Sent Events (SSE) 推送即時行情。伺服器每 30 秒發送 heartbeat 保持連線。
Shioaji uses Server-Sent Events (SSE) for real-time market data. The server sends a heartbeat every 30 seconds to keep connections alive.

Go 使用 `bufio.Scanner` 逐行讀取 SSE 串流。
Go uses `bufio.Scanner` to read the SSE stream line by line.

### 6.1 訂閱 | Subscribe

先透過 HTTP 訂閱，再開啟 SSE 連線。
Subscribe via HTTP first, then open the SSE connection.

```go
resp, err := client.Subscribe(shioaji.SubscriptionRequest{
    SecurityType: "STK",
    Exchange:     "TSE",
    Code:         "2330",
    QuoteType:    "Tick",
})
if err != nil {
    log.Fatal(err)
}
fmt.Println("訂閱結果 | Subscription:", resp.Message)
```

### 6.2 接收資料 | Receive Data

使用客戶端套件 | Using the client package:

```go
ctx, cancel := context.WithCancel(context.Background())
defer cancel()

err := client.StreamSSE(ctx, "/stream/data/tick_stk", func(event shioaji.SSEEvent) {
    switch event.Event {
    case "tick_stk":
        fmt.Printf("[TICK] %s\n", event.Data)
    case "heartbeat":
        fmt.Printf("[HEARTBEAT] %s\n", event.Data)
    }
})
if err != nil {
    log.Printf("SSE ended: %v", err)
}
```

使用 raw HTTP | Using raw HTTP:

```go
resp, err := http.Get("http://localhost:8080/api/v1/stream/data/tick_stk")
if err != nil {
    log.Fatal(err)
}
defer resp.Body.Close()

scanner := bufio.NewScanner(resp.Body)
var currentEvent string
for scanner.Scan() {
    line := scanner.Text()
    if strings.HasPrefix(line, "event:") {
        currentEvent = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
    } else if strings.HasPrefix(line, "data:") {
        data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
        fmt.Printf("[%s] %s\n", currentEvent, data)
    }
}
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

使用內建的重連功能 | Using the built-in reconnection:

```go
ctx, cancel := context.WithCancel(context.Background())
defer cancel()

// 最多重連 10 次 | Max 10 retries with exponential backoff
err := client.StreamSSEWithReconnect(ctx, "/stream/data/tick_stk",
    func(event shioaji.SSEEvent) {
        if event.Event == "tick_stk" {
            fmt.Printf("[TICK] %s\n", event.Data)
        }
    },
    10, // maxRetries，0 代表無限 | 0 for unlimited
)
```

手動重連 | Manual reconnection:

```go
func connectWithRetry(ctx context.Context, client *shioaji.Client) {
    maxRetries := 10
    for attempt := 0; attempt < maxRetries; attempt++ {
        err := client.StreamSSE(ctx, "/stream/data/tick_stk", func(event shioaji.SSEEvent) {
            fmt.Printf("[%s] %s\n", event.Event, event.Data)
        })
        if ctx.Err() != nil {
            return // context 已取消 | context cancelled
        }

        delay := time.Duration(1<<uint(attempt)) * time.Second
        if delay > 30*time.Second {
            delay = 30 * time.Second
        }
        log.Printf("Disconnected: %v. Reconnecting in %v...", err, delay)

        select {
        case <-time.After(delay):
        case <-ctx.Done():
            return
        }
    }
}
```

---

## 7. OpenAPI 客戶端產生 | OpenAPI Client Generation

使用 `oapi-codegen` 從 OpenAPI 規格自動產生型別和客戶端：
Use `oapi-codegen` to auto-generate types and client from the OpenAPI spec:

```bash
# 安裝 | Install
go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest

# 產生 Go 客戶端 | Generate Go client
oapi-codegen -package shioaji http://localhost:8080/openapi.json > pkg/shioaji/generated.go
```

也可以分開產生型別和客戶端 | Or generate types and client separately:

```bash
# 只產生型別 | Types only
oapi-codegen -generate types -package shioaji \
  http://localhost:8080/openapi.json > pkg/shioaji/types_gen.go

# 只產生客戶端 | Client only
oapi-codegen -generate client -package shioaji \
  http://localhost:8080/openapi.json > pkg/shioaji/client_gen.go
```

---

## 8. 完整範例 | Complete Runnable Example

`cmd/app/main.go` -- 啟動後即可執行的完整程式 | Ready-to-run complete program:

```go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"my-trading-app/pkg/shioaji"
)

func main() {
	// ================================================================
	// 初始化 | Initialize
	// ================================================================
	client := shioaji.NewClient("http://localhost:8080", "", "")

	// ================================================================
	// 1. 查詢帳戶 | List accounts
	// ================================================================
	accounts, err := client.ListAccounts()
	if err != nil {
		log.Fatalf("ListAccounts: %v", err)
	}
	fmt.Println("=== 帳戶 | Accounts ===")
	for _, acc := range accounts {
		fmt.Printf("  %s-%s (type=%s, signed=%v)\n",
			acc.BrokerID, acc.AccountID, acc.AccountType, acc.Signed)
	}

	// ================================================================
	// 2. 取得快照 | Get snapshots
	// ================================================================
	snapshots, err := client.Snapshots([]shioaji.ContractRequest{
		{SecurityType: "STK", Exchange: "TSE", Code: "2330"},
	})
	if err != nil {
		log.Fatalf("Snapshots: %v", err)
	}
	fmt.Println("\n=== 快照 | Snapshots ===")
	for _, snap := range snapshots {
		fmt.Printf("  %s: %.2f (change: %.2f)\n", snap.Code, snap.Close, snap.ChangePrice)
	}

	// ================================================================
	// 3. 訂閱即時行情 | Subscribe to real-time data
	// ================================================================
	subResp, err := client.Subscribe(shioaji.SubscriptionRequest{
		SecurityType: "STK",
		Exchange:     "TSE",
		Code:         "2330",
		QuoteType:    "Tick",
	})
	if err != nil {
		log.Fatalf("Subscribe: %v", err)
	}
	fmt.Printf("\n=== 訂閱結果 | Subscription ===\n  %s\n", subResp.Message)

	// ================================================================
	// 4. 接收 SSE 串流 | Receive SSE stream
	// ================================================================
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 按 Ctrl+C 優雅關閉 | Graceful shutdown on Ctrl+C
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\n收到中斷訊號，關閉串流... | Signal received, closing stream...")
		cancel()
	}()

	fmt.Println("\n串流中... Ctrl+C 結束 | Streaming... Ctrl+C to stop")

	err = client.StreamSSEWithReconnect(ctx, "/stream/data/tick_stk",
		func(event shioaji.SSEEvent) {
			switch event.Event {
			case "tick_stk":
				// 解析 tick 資料 | Parse tick data
				var tick map[string]any
				if err := json.Unmarshal([]byte(event.Data), &tick); err == nil {
					fmt.Printf("[TICK] %s price=%.2f vol=%.0f\n",
						tick["code"], tick["close"], tick["volume"])
				}
			case "heartbeat":
				var hb map[string]any
				if err := json.Unmarshal([]byte(event.Data), &hb); err == nil {
					fmt.Printf("[HEARTBEAT] %s\n", hb["timestamp"])
				}
			}
		},
		10,
	)
	if err != nil && err != context.Canceled {
		log.Printf("Stream ended: %v", err)
	}

	// ================================================================
	// 5. 下單範例（取消註解以執行）| Order example (uncomment to run)
	// ================================================================
	// trade, err := client.PlaceOrder(shioaji.PlaceOrderRequest{
	//     Contract: shioaji.ContractRequest{
	//         SecurityType: "STK",
	//         Exchange:     "TSE",
	//         Code:         "2330",
	//     },
	//     StockOrder: &shioaji.StockOrder{
	//         Action:    "Buy",
	//         Price:     600.0,
	//         Quantity:  1,
	//         PriceType: "LMT",
	//         OrderType: "ROD",
	//     },
	// })
	// if err != nil {
	//     log.Fatal(err)
	// }
	// fmt.Printf("Trade: %+v\n", trade)
}
```

**執行 | Run:**

```bash
go run cmd/app/main.go
```
