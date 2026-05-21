# C# Project Guide / C# 專案指南

Complete guide for building trading applications with Shioaji HTTP API in C#.

使用 Shioaji HTTP API 建立 C# 交易應用程式的完整指南。

---

## Table of Contents / 目錄

1. [Prerequisites / 前置需求](#prerequisites--前置需求)
2. [Project Setup / 專案建置](#project-setup--專案建置)
3. [Project Layout / 專案結構](#project-layout--專案結構)
4. [API Client / API 用戶端](#api-client--api-用戶端)
5. [HTTP Examples / HTTP 範例](#http-examples--http-範例)
   - [List Accounts / 查詢帳號](#list-accounts--查詢帳號)
   - [Snapshots / 快照報價](#snapshots--快照報價)
   - [Place Order / 下單](#place-order--下單)
6. [SSE Streaming / SSE 即時串流](#sse-streaming--sse-即時串流)
7. [OpenAPI Client Generation / OpenAPI 用戶端產生](#openapi-client-generation--openapi-用戶端產生)
8. [Complete Example / 完整範例](#complete-example--完整範例)

---

## Prerequisites / 前置需求

Start the Shioaji HTTP server before running any C# client code:

在執行 C# 用戶端之前，先啟動 Shioaji HTTP 伺服器：

```bash
uv tool install rshioaji
# or: curl -fsSL https://raw.githubusercontent.com/sinotrade/rshioaji/main/install.sh | sh
shioaji server start          # simulation mode by default
```

For remote/production servers, set your API credentials:

遠端或正式環境需設定 API 憑證：

```bash
export SJ_API_KEY=YOUR_API_KEY
export SJ_SEC_KEY=YOUR_SECRET_KEY
```

---

## Project Setup / 專案建置

```bash
dotnet new console -n MyTradingApp
cd MyTradingApp
```

### MyTradingApp.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <!-- System.Net.Http is included by default in .NET 6+ -->
    <!-- System.Text.Json is included by default in .NET 6+ -->
  </ItemGroup>
</Project>
```

No external NuGet packages are required. The built-in `System.Net.Http` and `System.Text.Json` handle everything.

不需要額外的 NuGet 套件。內建的 `System.Net.Http` 和 `System.Text.Json` 已足夠。

---

## Project Layout / 專案結構

```
MyTradingApp/
├── Shioaji/
│   ├── ShioajiClient.cs       # HTTP client with auth
│   ├── Models/
│   │   ├── Account.cs         # Account DTO
│   │   ├── Contract.cs        # Contract DTO
│   │   ├── Snapshot.cs        # Snapshot DTO
│   │   └── Order.cs           # Order DTOs
│   └── Streaming/
│       └── SseClient.cs       # SSE streaming client
├── Strategies/                # Trading strategy implementations
├── Program.cs                 # Entry point
└── MyTradingApp.csproj
```

---

## API Client / API 用戶端

### Models / 資料模型

```csharp
// Shioaji/Models/Account.cs
using System.Text.Json.Serialization;

namespace MyTradingApp.Shioaji.Models;

public record Account(
    [property: JsonPropertyName("account_type")] string AccountType,
    [property: JsonPropertyName("person_id")] string PersonId,
    [property: JsonPropertyName("broker_id")] string BrokerId,
    [property: JsonPropertyName("account_id")] string AccountId,
    [property: JsonPropertyName("username")] string Username
);
```

```csharp
// Shioaji/Models/Contract.cs
using System.Text.Json.Serialization;

namespace MyTradingApp.Shioaji.Models;

public record Contract(
    [property: JsonPropertyName("security_type")] string SecurityType,
    [property: JsonPropertyName("exchange")] string Exchange,
    [property: JsonPropertyName("code")] string Code
);
```

```csharp
// Shioaji/Models/Snapshot.cs
using System.Text.Json.Serialization;

namespace MyTradingApp.Shioaji.Models;

public record Snapshot(
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("close")] double Close,
    [property: JsonPropertyName("total_volume")] long TotalVolume,
    [property: JsonPropertyName("change_price")] double ChangePrice,
    [property: JsonPropertyName("change_rate")] double ChangeRate
);
```

```csharp
// Shioaji/Models/Order.cs
using System.Text.Json.Serialization;

namespace MyTradingApp.Shioaji.Models;

public record StockOrder(
    [property: JsonPropertyName("action")] string Action,
    [property: JsonPropertyName("price")] double Price,
    [property: JsonPropertyName("quantity")] int Quantity,
    [property: JsonPropertyName("price_type")] string PriceType,
    [property: JsonPropertyName("order_type")] string OrderType
);

public record PlaceOrderRequest(
    [property: JsonPropertyName("contract")] Contract Contract,
    [property: JsonPropertyName("stock_order")] StockOrder? StockOrder = null,
    [property: JsonPropertyName("futures_order")] object? FuturesOrder = null
);

public record SubscriptionRequest(
    [property: JsonPropertyName("security_type")] string SecurityType,
    [property: JsonPropertyName("exchange")] string Exchange,
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("quote_type")] string QuoteType,
    [property: JsonPropertyName("intraday_odd")] bool IntradayOdd = false
);

public record SubscriptionResponse(
    [property: JsonPropertyName("success")] bool Success,
    [property: JsonPropertyName("message")] string Message
);
```

### ShioajiClient / 用戶端類別

```csharp
// Shioaji/ShioajiClient.cs
using System.Net.Http.Json;
using System.Text.Json;
using MyTradingApp.Shioaji.Models;

namespace MyTradingApp.Shioaji;

/// <summary>
/// HTTP client for the Shioaji API server.
/// Shioaji API 伺服器的 HTTP 用戶端。
/// </summary>
public class ShioajiClient : IDisposable
{
    private readonly HttpClient _http;
    private readonly JsonSerializerOptions _jsonOptions;

    /// <summary>
    /// Create client for local server (no auth needed).
    /// 建立本地伺服器用戶端（不需認證）。
    /// </summary>
    public ShioajiClient(string baseUrl = "http://localhost:8080")
    {
        _http = new HttpClient { BaseAddress = new Uri(baseUrl) };
        _http.DefaultRequestHeaders.Add("Accept", "application/json");
        _jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
        };
    }

    /// <summary>
    /// Create client for remote server with API key authentication.
    /// 建立遠端伺服器用戶端（需 API 金鑰認證）。
    /// Auth header: "Authorization: Bearer API_KEY:SECRET_KEY"
    /// Only needed for non-localhost connections.
    /// 僅在非本地連線時需要認證。
    /// </summary>
    public ShioajiClient(string baseUrl, string apiKey, string secretKey)
        : this(baseUrl)
    {
        _http.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $"{apiKey}:{secretKey}");
    }

    // --- Auth endpoints / 認證端點 ---

    /// <summary>
    /// List trading accounts.
    /// 查詢交易帳號。
    /// GET /api/v1/auth/accounts
    /// </summary>
    public async Task<List<Account>> ListAccountsAsync()
    {
        var resp = await _http.GetAsync("/api/v1/auth/accounts");
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadFromJsonAsync<List<Account>>(_jsonOptions)
               ?? throw new InvalidOperationException("Null response");
    }

    // --- Data endpoints / 資料端點 ---

    /// <summary>
    /// Fetch market snapshots.
    /// 取得快照報價。
    /// POST /api/v1/data/snapshots
    /// </summary>
    public async Task<List<Snapshot>> GetSnapshotsAsync(params Contract[] contracts)
    {
        var body = new { contracts };
        var resp = await _http.PostAsJsonAsync("/api/v1/data/snapshots", body, _jsonOptions);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadFromJsonAsync<List<Snapshot>>(_jsonOptions)
               ?? throw new InvalidOperationException("Null response");
    }

    // --- Order endpoints / 委託端點 ---

    /// <summary>
    /// Place a stock order.
    /// 下單（股票）。
    /// POST /api/v1/order/place_order
    /// </summary>
    public async Task<JsonElement> PlaceOrderAsync(PlaceOrderRequest order)
    {
        var resp = await _http.PostAsJsonAsync("/api/v1/order/place_order", order, _jsonOptions);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadFromJsonAsync<JsonElement>();
    }

    // --- Stream endpoints / 串流端點 ---

    /// <summary>
    /// Subscribe to market data stream.
    /// 訂閱行情串流。
    /// POST /api/v1/stream/subscribe
    /// </summary>
    public async Task<SubscriptionResponse> SubscribeAsync(SubscriptionRequest request)
    {
        var resp = await _http.PostAsJsonAsync("/api/v1/stream/subscribe", request, _jsonOptions);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadFromJsonAsync<SubscriptionResponse>(_jsonOptions)
               ?? throw new InvalidOperationException("Null response");
    }

    /// <summary>
    /// Get the underlying HttpClient for SSE streaming.
    /// 取得底層 HttpClient 以進行 SSE 串流。
    /// </summary>
    public HttpClient Http => _http;

    public void Dispose() => _http.Dispose();
}
```

---

## HTTP Examples / HTTP 範例

### List Accounts / 查詢帳號

```csharp
using var client = new ShioajiClient();

// GET /api/v1/auth/accounts
var accounts = await client.ListAccountsAsync();
foreach (var acct in accounts)
{
    Console.WriteLine($"{acct.AccountType} {acct.BrokerId}-{acct.AccountId} {acct.Username}");
}
```

### Snapshots / 快照報價

```csharp
// POST /api/v1/data/snapshots
var snapshots = await client.GetSnapshotsAsync(
    new Contract("STK", "TSE", "2330"),
    new Contract("STK", "TSE", "2317")
);

foreach (var snap in snapshots)
{
    Console.WriteLine($"{snap.Code}: {snap.Close} vol={snap.TotalVolume}");
}
```

### Place Order / 下單

```csharp
// POST /api/v1/order/place_order
var order = new PlaceOrderRequest(
    Contract: new Contract("STK", "TSE", "2330"),
    StockOrder: new StockOrder(
        Action: "Buy",
        Price: 580.0,
        Quantity: 1,
        PriceType: "LMT",
        OrderType: "ROD"
    )
);

var result = await client.PlaceOrderAsync(order);
Console.WriteLine($"Order result: {result}");
```

---

## SSE Streaming / SSE 即時串流

C# uses `HttpClient.GetStreamAsync` + `StreamReader` for SSE consumption, with an `IAsyncEnumerable` pattern for clean iteration.

C# 使用 `HttpClient.GetStreamAsync` + `StreamReader` 消費 SSE，搭配 `IAsyncEnumerable` 模式實現乾淨的迭代。

### SseClient / SSE 用戶端

```csharp
// Shioaji/Streaming/SseClient.cs
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace MyTradingApp.Shioaji.Streaming;

/// <summary>
/// A single SSE event with event name and data payload.
/// 單一 SSE 事件，包含事件名稱與資料酬載。
/// </summary>
public record SseEvent(string EventName, string Data)
{
    /// <summary>
    /// Parse the data payload as JSON.
    /// 將資料酬載解析為 JSON。
    /// </summary>
    public JsonElement AsJson() => JsonDocument.Parse(Data).RootElement;
}

/// <summary>
/// SSE streaming client using async enumerable pattern.
/// 使用非同步可列舉模式的 SSE 串流用戶端。
/// </summary>
public static class SseClient
{
    /// <summary>
    /// Stream SSE events from an endpoint as an async enumerable.
    /// 以非同步可列舉方式串流 SSE 事件。
    ///
    /// Usage:
    /// await foreach (var evt in SseClient.StreamAsync(httpClient, "/api/v1/stream/data/tick_stk"))
    /// {
    ///     Console.WriteLine($"[{evt.EventName}] {evt.Data}");
    /// }
    /// </summary>
    public static async IAsyncEnumerable<SseEvent> StreamAsync(
        HttpClient http,
        string path,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        request.Headers.Accept.Add(new("text/event-stream"));

        using var response = await http.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            ct);
        response.EnsureSuccessStatusCode();

        using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var reader = new StreamReader(stream);

        string currentEvent = "";

        while (!ct.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(ct);
            if (line is null) break;  // Stream closed

            if (line.StartsWith("event:"))
            {
                currentEvent = line[6..].TrimStart();
            }
            else if (line.StartsWith("data:"))
            {
                var data = line[5..].TrimStart();
                yield return new SseEvent(currentEvent, data);
            }
            else if (line == "")
            {
                currentEvent = "";  // Reset per SSE spec
            }
        }
    }
}
```

### Streaming Usage / 串流使用方式

```csharp
using var client = new ShioajiClient();

// Step 1: Subscribe / 步驟 1: 訂閱
await client.SubscribeAsync(new SubscriptionRequest("STK", "TSE", "2330", "Tick"));

// Step 2: Stream with async enumerable / 步驟 2: 以非同步可列舉串流
using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

Console.WriteLine("Streaming ticks (Ctrl+C to stop)...");
await foreach (var evt in SseClient.StreamAsync(
    client.Http, "/api/v1/stream/data/tick_stk", cts.Token))
{
    if (evt.EventName == "tick_stk")
    {
        var tick = evt.AsJson();
        Console.WriteLine($"[{evt.EventName}] code={tick.GetProperty("code")} " +
                          $"close={tick.GetProperty("close")}");
    }
}
```

### SSE Endpoints / SSE 端點

| Endpoint | Event Name | Description |
|----------|-----------|-------------|
| `GET /api/v1/stream/data/tick_stk` | `tick_stk` | Stock tick data / 股票逐筆成交 |
| `GET /api/v1/stream/data/bidask_stk` | `bidask_stk` | Stock bid/ask data / 股票五檔報價 |
| `GET /api/v1/stream/data/quote_stk` | `quote_stk` | Stock quote data / 股票行情 |
| `GET /api/v1/stream/data/tick_fop` | `tick_fop` | Futures/options tick / 期權逐筆 |
| `GET /api/v1/stream/data/bidask_fop` | `bidask_fop` | Futures/options bid/ask / 期權五檔 |
| `GET /api/v1/stream/data/quote_fop` | `quote_fop` | Futures/options quote / 期權行情 |
| `GET /api/v1/stream/data/order_event` | `order_event` | Order events / 委託回報 |
| `GET /api/v1/stream/data` | (all above) | Combined stream / 合併串流 |

---

## OpenAPI Client Generation / OpenAPI 用戶端產生

Auto-generate a fully typed C# client from the server's OpenAPI spec using NSwag.

使用 NSwag 從伺服器的 OpenAPI 規格自動產生完整型別的 C# 用戶端。

```bash
# Install NSwag CLI / 安裝 NSwag CLI
dotnet tool install -g NSwag.ConsoleCore

# Generate client (server must be running) / 產生用戶端（伺服器須執行中）
nswag openapi2csclient \
  /input:http://localhost:8080/openapi.json \
  /output:Shioaji/Generated/ShioajiClient.cs \
  /namespace:MyTradingApp.Shioaji.Generated \
  /classname:ShioajiApiClient \
  /generateClientInterfaces:true
```

This generates a complete typed client with all endpoints, request/response DTOs, and async methods. You can use it alongside or instead of the manual client above.

這會產生包含所有端點、請求/回應 DTO 和非同步方法的完整型別用戶端。可與上方的手動用戶端並用或替代使用。

```csharp
// Using generated client / 使用自動產生的用戶端
using MyTradingApp.Shioaji.Generated;

var apiClient = new ShioajiApiClient("http://localhost:8080", new HttpClient());
var accounts = await apiClient.AccountsAsync();
```

---

## Complete Example / 完整範例

A single-file runnable example that lists accounts, fetches a snapshot, and streams ticks.

單一檔案可執行範例：查詢帳號、取得快照、串流逐筆資料。

### Program.cs

```csharp
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;

// ---------- Data models / 資料模型 ----------

record Account(
    [property: JsonPropertyName("account_type")] string AccountType,
    [property: JsonPropertyName("broker_id")] string BrokerId,
    [property: JsonPropertyName("account_id")] string AccountId,
    [property: JsonPropertyName("username")] string Username
);

record Contract(
    [property: JsonPropertyName("security_type")] string SecurityType,
    [property: JsonPropertyName("exchange")] string Exchange,
    [property: JsonPropertyName("code")] string Code
);

record SnapshotResponse(
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("close")] double Close,
    [property: JsonPropertyName("total_volume")] long TotalVolume
);

// ---------- SSE helper / SSE 輔助 ----------

static async IAsyncEnumerable<(string Event, string Data)> ReadSseAsync(
    HttpClient http,
    string path,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    using var request = new HttpRequestMessage(HttpMethod.Get, path);
    request.Headers.Accept.Add(new("text/event-stream"));

    using var response = await http.SendAsync(
        request, HttpCompletionOption.ResponseHeadersRead, ct);
    response.EnsureSuccessStatusCode();

    using var stream = await response.Content.ReadAsStreamAsync(ct);
    using var reader = new StreamReader(stream);

    var currentEvent = "";
    while (!ct.IsCancellationRequested)
    {
        var line = await reader.ReadLineAsync(ct);
        if (line is null) break;

        if (line.StartsWith("event:"))
            currentEvent = line[6..].TrimStart();
        else if (line.StartsWith("data:"))
            yield return (currentEvent, line[5..].TrimStart());
        else if (line == "")
            currentEvent = "";
    }
}

// ---------- Main / 主程式 ----------

var baseUrl = "http://localhost:8080";
using var http = new HttpClient { BaseAddress = new Uri(baseUrl) };
// For remote server, uncomment:
// http.DefaultRequestHeaders.Authorization =
//     new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "YOUR_API_KEY:YOUR_SECRET_KEY");

try
{
    // 1. List accounts / 查詢帳號
    Console.WriteLine("=== Accounts ===");
    var accounts = await http.GetFromJsonAsync<List<Account>>("/api/v1/auth/accounts");
    foreach (var acct in accounts!)
    {
        Console.WriteLine($"  {acct.AccountType} {acct.BrokerId}-{acct.AccountId} {acct.Username}");
    }

    // 2. Fetch snapshot / 取得快照
    Console.WriteLine("\n=== Snapshot: 2330 ===");
    var snapResp = await http.PostAsJsonAsync("/api/v1/data/snapshots", new
    {
        contracts = new[] { new { security_type = "STK", exchange = "TSE", code = "2330" } }
    });
    snapResp.EnsureSuccessStatusCode();
    var snapshots = await snapResp.Content.ReadFromJsonAsync<List<SnapshotResponse>>();
    foreach (var snap in snapshots!)
    {
        Console.WriteLine($"  {snap.Code}: {snap.Close} vol={snap.TotalVolume}");
    }

    // 3. Subscribe to tick stream / 訂閱逐筆串流
    Console.WriteLine("\n=== Subscribing to 2330 ticks ===");
    var subResp = await http.PostAsJsonAsync("/api/v1/stream/subscribe", new
    {
        security_type = "STK",
        exchange = "TSE",
        code = "2330",
        quote_type = "Tick"
    });
    subResp.EnsureSuccessStatusCode();
    var subResult = await subResp.Content.ReadAsStringAsync();
    Console.WriteLine($"  {subResult}");

    // 4. Stream SSE data (Ctrl+C to stop) / 串流 SSE 資料（Ctrl+C 停止）
    Console.WriteLine("\n=== Streaming ticks (Ctrl+C to stop) ===");
    using var cts = new CancellationTokenSource();
    Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

    await foreach (var (evt, data) in ReadSseAsync(http, "/api/v1/stream/data/tick_stk", cts.Token))
    {
        if (evt == "tick_stk")
        {
            var tick = JsonDocument.Parse(data).RootElement;
            Console.WriteLine($"  [{evt}] code={tick.GetProperty("code")} close={tick.GetProperty("close")}");
        }
    }
}
catch (OperationCanceledException)
{
    Console.WriteLine("\nStopped.");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
}
```

### Run / 執行

```bash
dotnet run
```

---

## Authentication Notes / 認證說明

| Scenario | Auth Header |
|----------|-------------|
| **localhost** (default) | Not required / 不需要 |
| **Remote server** | `Authorization: Bearer <SJ_API_KEY>:<SJ_SEC_KEY>` |

When connecting to a remote server, set the auth header on `HttpClient`:

連接遠端伺服器時，在 `HttpClient` 上設定認證標頭：

```csharp
using var client = new ShioajiClient(
    "https://your-server.com",
    "YOUR_API_KEY",
    "YOUR_SECRET_KEY"
);
```

---

## API Endpoint Reference / API 端點參考

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/auth/accounts` | List accounts / 查詢帳號 |
| POST | `/api/v1/data/snapshots` | Market snapshots / 快照報價 |
| POST | `/api/v1/data/ticks` | Historical ticks / 歷史逐筆 |
| POST | `/api/v1/data/kbars` | K-bar data / K 線資料 |
| POST | `/api/v1/order/place_order` | Place order / 下單 |
| POST | `/api/v1/order/cancel_order` | Cancel order / 刪單 |
| POST | `/api/v1/order/update_status` | Update order status / 更新委託狀態 |
| GET | `/api/v1/portfolio/account_balance` | Account balance / 帳戶餘額 |
| POST | `/api/v1/stream/subscribe` | Subscribe to stream / 訂閱串流 |
| GET | `/api/v1/stream/data/tick_stk` | SSE tick stream / 逐筆串流 |

For the full endpoint list, see [HTTP_API.md](HTTP_API.md).
