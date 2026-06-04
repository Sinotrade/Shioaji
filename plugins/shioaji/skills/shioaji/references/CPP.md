# C/C++ HTTP/SSE Client Patterns

Transport guide for building C/C++ applications that call the Shioaji HTTP API and consume SSE streams.

本文件說明 C/C++ 如何送 HTTP request、處理 JSON response、消費 SSE 串流。它不是 endpoint payload 或 response schema catalog。

---

## Table of Contents / 目錄

1. [Prerequisites / 前置需求](#prerequisites--前置需求)
2. [Project Setup / 專案建置](#project-setup--專案建置)
3. [Project Layout / 專案結構](#project-layout--專案結構)
4. [Dependencies / 依賴套件](#dependencies--依賴套件)
5. [API Client / API 用戶端](#api-client--api-用戶端)
6. [HTTP Examples / HTTP 範例](#http-examples--http-範例)
   - [List Accounts / 查詢帳號](#list-accounts--查詢帳號)
   - [Snapshots / 快照報價](#snapshots--快照報價)
   - [Place Order / 下單](#place-order--下單)
7. [SSE Streaming / SSE 即時串流](#sse-streaming--sse-即時串流)
8. [Complete Example / 完整範例](#complete-example--完整範例)
9. [Endpoint Inventory / 端點清單](#endpoint-inventory--端點清單)
10. [OpenAPI Client Generation / OpenAPI 客戶端生成](#openapi-client-generation--openapi-客戶端生成)

---

## Prerequisites / 前置需求

Start the Shioaji HTTP server before running any C/C++ client code:

在執行 C/C++ 用戶端之前，先啟動 Shioaji HTTP 伺服器：

```bash
uv tool install shioaji
# or: curl -fsSL https://raw.githubusercontent.com/sinotrade/shioaji/main/install.sh | sh
shioaji server start          # simulation mode by default
```

Before starting the server, configure `.env` in the server working directory or export equivalent variables: `SJ_API_KEY`, `SJ_SEC_KEY`, `SJ_CA_PATH`, `SJ_CA_PASSWD`, and `SJ_PRODUCTION`. Use `SJ_PRODUCTION=false` while testing language clients unless the user explicitly needs production mode. See [PREPARE.md](PREPARE.md) for full setup, certificate, and `.env` details.

Use the matching functional reference for workflow, payload rules, response shapes, and branching decisions. Use [HTTP_API.md](HTTP_API.md) for endpoint inventory. The hand-written DTOs below are starter transport types; fetch `/openapi.json` for production clients.

This language guide is transport-only. Do not restate or override shared HTTP rules here: order update/cancel `trade_id`, `order_deal_event` over SSE, simulation vs production, and SSE payload field types are governed by [HTTP_API.md](HTTP_API.md) and the matching functional reference.

---

## Project Setup / 專案建置

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
project(my-trading-app LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(CURL REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_executable(trading
    src/main.cpp
    src/shioaji/client.cpp
    src/shioaji/stream.cpp
)

target_include_directories(trading PRIVATE src)
target_link_libraries(trading PRIVATE CURL::libcurl nlohmann_json::nlohmann_json)
```

### vcpkg.json

```json
{
  "name": "my-trading-app",
  "version-string": "1.0.0",
  "dependencies": [
    "curl",
    "nlohmann-json"
  ]
}
```

### Build / 編譯

```bash
# With vcpkg
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build build

# Or without vcpkg (if deps installed via system package manager)
cmake -B build -S .
cmake --build build
```

---

## Project Layout / 專案結構

```
my-trading-app/
├── src/
│   ├── shioaji/
│   │   ├── client.h          # HTTP client class declaration
│   │   ├── client.cpp        # HTTP client implementation
│   │   ├── types.h           # Data types and JSON parsing
│   │   ├── stream.h          # SSE streaming declaration
│   │   └── stream.cpp        # SSE streaming implementation
│   ├── strategies/           # Trading strategy implementations
│   └── main.cpp              # Entry point
├── CMakeLists.txt
└── vcpkg.json
```

---

## Dependencies / 依賴套件

| Library | Purpose | Install |
|---------|---------|---------|
| **libcurl** | HTTP requests + SSE streaming | `vcpkg install curl` or system package |
| **nlohmann/json** | JSON serialization/deserialization | `vcpkg install nlohmann-json` |

---

## API Client / API 用戶端

### types.h — Data Types / 資料型別

```cpp
#pragma once
#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <optional>

namespace shioaji {

struct Account {
    std::string account_type;  // "S" (stock) or "F" (futures)
    std::string person_id;
    std::string broker_id;
    std::string account_id;
    std::string username;
};

void from_json(const nlohmann::json& j, Account& a) {
    j.at("account_type").get_to(a.account_type);
    j.at("person_id").get_to(a.person_id);
    j.at("broker_id").get_to(a.broker_id);
    j.at("account_id").get_to(a.account_id);
    j.at("username").get_to(a.username);
}

struct Contract {
    std::string security_type;  // "STK", "FUT", "OPT", "IND"
    std::string exchange;       // "TSE", "OTC", "TAIFEX"
    std::string code;
    std::optional<std::string> target_code;
};

void to_json(nlohmann::json& j, const Contract& c) {
    j = nlohmann::json{
        {"security_type", c.security_type},
        {"exchange", c.exchange},
        {"code", c.code}
    };
    if (c.target_code) j["target_code"] = *c.target_code;
}

struct Snapshot {
    std::string datetime;  // HTTP Snapshot uses datetime; Python api.snapshots() exposes ts.
    double close;
    int64_t total_volume;
    std::string code;
    double change_price;
    double change_rate;
};

void from_json(const nlohmann::json& j, Snapshot& s) {
    j.at("datetime").get_to(s.datetime);
    j.at("close").get_to(s.close);
    j.at("total_volume").get_to(s.total_volume);
    j.at("code").get_to(s.code);
    if (j.contains("change_price")) j.at("change_price").get_to(s.change_price);
    if (j.contains("change_rate")) j.at("change_rate").get_to(s.change_rate);
}

struct StockOrder {
    std::string action;      // "Buy" or "Sell"
    double price;
    int quantity;
    std::string price_type;  // "LMT", "MKT", "MKP"
    std::string order_type;  // "ROD", "IOC", "FOK"
};

void to_json(nlohmann::json& j, const StockOrder& o) {
    j = nlohmann::json{
        {"action", o.action},
        {"price", o.price},
        {"quantity", o.quantity},
        {"price_type", o.price_type},
        {"order_type", o.order_type}
    };
}

}  // namespace shioaji
```

### client.h — ShioajiClient Declaration / 用戶端宣告

```cpp
#pragma once
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <string>
#include <optional>

namespace shioaji {

class ShioajiClient {
public:
    /// Construct client for local server (no auth needed).
    /// 建立本地伺服器用戶端（不需認證）。
    explicit ShioajiClient(const std::string& base_url = "http://localhost:8080");

    /// Construct client for remote server with API key authentication.
    /// 建立遠端伺服器用戶端（需 API 金鑰認證）。
    ShioajiClient(const std::string& base_url,
                  const std::string& api_key,
                  const std::string& secret_key);

    ~ShioajiClient();

    // Disable copy (CURL handle is not copyable)
    ShioajiClient(const ShioajiClient&) = delete;
    ShioajiClient& operator=(const ShioajiClient&) = delete;

    /// GET request, returns parsed JSON.
    nlohmann::json get(const std::string& path);

    /// POST request with JSON body, returns parsed JSON.
    nlohmann::json post(const std::string& path, const nlohmann::json& body);

    /// GET request for SSE stream — calls callback for each "data:" line.
    /// SSE 串流請求 — 每收到 "data:" 行時呼叫回呼函式。
    void get_stream(const std::string& path,
                    std::function<void(const std::string& event, const std::string& data)> callback);

private:
    std::string base_url_;
    std::optional<std::string> auth_header_;
    CURL* curl_;
    struct curl_slist* default_headers_;

    void setup_auth(const std::string& api_key, const std::string& secret_key);
    static size_t write_callback(char* ptr, size_t size, size_t nmemb, void* userdata);
    static size_t sse_callback(char* ptr, size_t size, size_t nmemb, void* userdata);
};

}  // namespace shioaji
```

### client.cpp — ShioajiClient Implementation / 用戶端實作

```cpp
#include "shioaji/client.h"
#include <stdexcept>
#include <sstream>

namespace shioaji {

ShioajiClient::ShioajiClient(const std::string& base_url)
    : base_url_(base_url), curl_(curl_easy_init()), default_headers_(nullptr) {
    if (!curl_) throw std::runtime_error("Failed to initialize libcurl");
    default_headers_ = curl_slist_append(default_headers_, "Content-Type: application/json");
}

ShioajiClient::ShioajiClient(const std::string& base_url,
                             const std::string& api_key,
                             const std::string& secret_key)
    : ShioajiClient(base_url) {
    setup_auth(api_key, secret_key);
}

ShioajiClient::~ShioajiClient() {
    if (default_headers_) curl_slist_free_all(default_headers_);
    if (curl_) curl_easy_cleanup(curl_);
}

void ShioajiClient::setup_auth(const std::string& api_key, const std::string& secret_key) {
    // Auth: "Authorization: Bearer <API_KEY>:<SECRET_KEY>"
    // Only needed for non-localhost connections.
    // 僅在非本地連線時需要認證。
    auth_header_ = "Authorization: Bearer " + api_key + ":" + secret_key;
    default_headers_ = curl_slist_append(default_headers_, auth_header_->c_str());
}

size_t ShioajiClient::write_callback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* response = static_cast<std::string*>(userdata);
    response->append(ptr, size * nmemb);
    return size * nmemb;
}

nlohmann::json ShioajiClient::get(const std::string& path) {
    std::string response;
    std::string url = base_url_ + path;

    curl_easy_reset(curl_);
    curl_easy_setopt(curl_, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl_, CURLOPT_HTTPHEADER, default_headers_);
    curl_easy_setopt(curl_, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl_, CURLOPT_WRITEDATA, &response);

    CURLcode res = curl_easy_perform(curl_);
    if (res != CURLE_OK) {
        throw std::runtime_error(std::string("GET failed: ") + curl_easy_strerror(res));
    }

    long http_code = 0;
    curl_easy_getinfo(curl_, CURLINFO_RESPONSE_CODE, &http_code);
    if (http_code >= 400) {
        throw std::runtime_error("HTTP " + std::to_string(http_code) + ": " + response);
    }

    return nlohmann::json::parse(response);
}

nlohmann::json ShioajiClient::post(const std::string& path, const nlohmann::json& body) {
    std::string response;
    std::string url = base_url_ + path;
    std::string body_str = body.dump();

    curl_easy_reset(curl_);
    curl_easy_setopt(curl_, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl_, CURLOPT_HTTPHEADER, default_headers_);
    curl_easy_setopt(curl_, CURLOPT_POSTFIELDS, body_str.c_str());
    curl_easy_setopt(curl_, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl_, CURLOPT_WRITEDATA, &response);

    CURLcode res = curl_easy_perform(curl_);
    if (res != CURLE_OK) {
        throw std::runtime_error(std::string("POST failed: ") + curl_easy_strerror(res));
    }

    long http_code = 0;
    curl_easy_getinfo(curl_, CURLINFO_RESPONSE_CODE, &http_code);
    if (http_code >= 400) {
        throw std::runtime_error("HTTP " + std::to_string(http_code) + ": " + response);
    }

    return nlohmann::json::parse(response);
}

// SSE parsing context
struct SseContext {
    std::string buffer;
    std::string current_event;
    std::function<void(const std::string&, const std::string&)> callback;
};

size_t ShioajiClient::sse_callback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* ctx = static_cast<SseContext*>(userdata);
    size_t total = size * nmemb;
    ctx->buffer.append(ptr, total);

    // Process complete lines
    size_t pos;
    while ((pos = ctx->buffer.find('\n')) != std::string::npos) {
        std::string line = ctx->buffer.substr(0, pos);
        ctx->buffer.erase(0, pos + 1);

        // Remove trailing \r
        if (!line.empty() && line.back() == '\r') line.pop_back();

        if (line.rfind("event:", 0) == 0) {
            ctx->current_event = line.substr(6);
            // Trim leading space
            if (!ctx->current_event.empty() && ctx->current_event[0] == ' ')
                ctx->current_event.erase(0, 1);
        } else if (line.rfind("data:", 0) == 0) {
            std::string data = line.substr(5);
            if (!data.empty() && data[0] == ' ') data.erase(0, 1);
            ctx->callback(ctx->current_event, data);
        }
        // Empty line resets event name (per SSE spec)
        if (line.empty()) ctx->current_event.clear();
    }

    return total;
}

void ShioajiClient::get_stream(
    const std::string& path,
    std::function<void(const std::string& event, const std::string& data)> callback) {
    std::string url = base_url_ + path;

    SseContext ctx;
    ctx.callback = std::move(callback);

    curl_easy_reset(curl_);
    curl_easy_setopt(curl_, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl_, CURLOPT_HTTPHEADER, default_headers_);
    curl_easy_setopt(curl_, CURLOPT_WRITEFUNCTION, sse_callback);
    curl_easy_setopt(curl_, CURLOPT_WRITEDATA, &ctx);
    // Disable buffering for real-time streaming
    curl_easy_setopt(curl_, CURLOPT_TCP_NODELAY, 1L);

    CURLcode res = curl_easy_perform(curl_);  // Blocks, streams to callback
    if (res != CURLE_OK && res != CURLE_WRITE_ERROR) {
        throw std::runtime_error(std::string("SSE stream failed: ") + curl_easy_strerror(res));
    }
}

}  // namespace shioaji
```

---

## HTTP Examples / HTTP 範例

### List Accounts / 查詢帳號

```cpp
#include "shioaji/client.h"
#include "shioaji/types.h"
#include <iostream>

// GET /api/v1/auth/accounts
auto client = shioaji::ShioajiClient("http://localhost:8080");
auto json = client.get("/api/v1/auth/accounts");
auto accounts = json.get<std::vector<shioaji::Account>>();

for (const auto& acct : accounts) {
    std::cout << acct.account_type << " " << acct.broker_id
              << "-" << acct.account_id << " " << acct.username << "\n";
}
```

### Snapshots / 快照報價

```cpp
// POST /api/v1/data/snapshots
nlohmann::json body = {
    {"contracts", {
        {{"security_type", "STK"}, {"exchange", "TSE"}, {"code", "2330"}},
        {{"security_type", "STK"}, {"exchange", "TSE"}, {"code", "2317"}}
    }}
};

auto json = client.post("/api/v1/data/snapshots", body);
auto snapshots = json.get<std::vector<shioaji::Snapshot>>();

for (const auto& snap : snapshots) {
    std::cout << snap.code << ": " << snap.close
              << " vol=" << snap.total_volume << "\n";
}
```

### Place Order / 下單

Keep order examples disabled in runnable code. Confirm account, production/simulation mode, payload rules, response status, and `order_deal_event` handling in [ORDERS.md](ORDERS.md) before enabling.

```cpp
// POST /api/v1/order/place_order
// nlohmann::json order_body = {
//     {"contract", {
//         {"security_type", "STK"},
//         {"exchange", "TSE"},
//         {"code", "2330"}
//     }},
//     {"stock_order", {
//         {"action", "Buy"},
//         {"price", 580.0},
//         {"quantity", 1},
//         {"price_type", "LMT"},
//         {"order_type", "ROD"}
//     }}
// };
//
// auto result = client.post("/api/v1/order/place_order", order_body);
// std::cout << "Order result: " << result.dump(2) << "\n";
```

---

## SSE Streaming / SSE 即時串流

Subscribe to a contract, then consume the SSE event stream.

先訂閱合約，再消費 SSE 事件串流。

### stream.h

```cpp
#pragma once
#include "shioaji/client.h"
#include <functional>
#include <string>
#include <atomic>
#include <thread>

namespace shioaji {

class TickStream {
public:
    explicit TickStream(ShioajiClient& client);
    ~TickStream();

    /// Subscribe and start streaming tick data for a stock.
    /// 訂閱並開始串流股票逐筆成交資料。
    void start(const std::string& exchange, const std::string& code,
               std::function<void(const nlohmann::json&)> on_tick);

    void stop();

private:
    ShioajiClient& client_;
    std::atomic<bool> running_{false};
    std::thread stream_thread_;
};

}  // namespace shioaji
```

### stream.cpp

```cpp
#include "shioaji/stream.h"

namespace shioaji {

TickStream::TickStream(ShioajiClient& client) : client_(client) {}

TickStream::~TickStream() { stop(); }

void TickStream::start(const std::string& exchange, const std::string& code,
                       std::function<void(const nlohmann::json&)> on_tick) {
    // Step 1: Subscribe
    // 步驟 1: 訂閱
    nlohmann::json sub_body = {
        {"security_type", "STK"},
        {"exchange", exchange},
        {"code", code},
        {"quote_type", "Tick"}
    };
    client_.post("/api/v1/stream/subscribe", sub_body);

    // Step 2: Connect to SSE stream
    // 步驟 2: 連接 SSE 串流
    running_ = true;
    stream_thread_ = std::thread([this, on_tick = std::move(on_tick)]() {
        client_.get_stream("/api/v1/stream/data/tick_stk",
            [this, &on_tick](const std::string& event, const std::string& data) {
                if (!running_) return;
                if (event == "tick_stk") {
                    auto json = nlohmann::json::parse(data, nullptr, false);
                    if (!json.is_discarded()) {
                        on_tick(json);
                    }
                }
            });
    });
}

void TickStream::stop() {
    running_ = false;
    if (stream_thread_.joinable()) stream_thread_.join();
}

}  // namespace shioaji
```

For futures continuous-month aliases such as `TXFR1` / `TXFR2`, first call `GET /api/v1/data/contracts/TXFR1?security_type=FUT` and copy the returned `target_code` into the subscribe request. Regular futures codes do not need `target_code`.

Order events use a separate account subscription in production. Before opening `/api/v1/stream/data/order_event`, call `POST /api/v1/auth/subscribe_trade` once per account; simulation does not require it.

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

## Complete Example / 完整範例

A single-file compilable example that lists accounts, fetches a snapshot, and streams ticks.

單一檔案可編譯範例：查詢帳號、取得快照、串流逐筆資料。

### main.cpp

```cpp
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <iostream>
#include <string>
#include <functional>
#include <stdexcept>
#include <csignal>
#include <atomic>

using json = nlohmann::json;

// ---------- Minimal inline client ----------

static std::atomic<bool> g_running{true};

static void signal_handler(int) { g_running = false; }

static size_t write_cb(char* ptr, size_t size, size_t nmemb, void* ud) {
    auto* s = static_cast<std::string*>(ud);
    s->append(ptr, size * nmemb);
    return size * nmemb;
}

struct SseCtx {
    std::string buf;
    std::string evt;
    std::function<void(const std::string&, const std::string&)> cb;
};

static size_t sse_cb(char* ptr, size_t size, size_t nmemb, void* ud) {
    if (!g_running) return 0;  // Abort stream
    auto* ctx = static_cast<SseCtx*>(ud);
    size_t total = size * nmemb;
    ctx->buf.append(ptr, total);
    size_t pos;
    while ((pos = ctx->buf.find('\n')) != std::string::npos) {
        std::string line = ctx->buf.substr(0, pos);
        ctx->buf.erase(0, pos + 1);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.rfind("event:", 0) == 0) {
            ctx->evt = line.substr(6);
            if (!ctx->evt.empty() && ctx->evt[0] == ' ') ctx->evt.erase(0, 1);
        } else if (line.rfind("data:", 0) == 0) {
            std::string data = line.substr(5);
            if (!data.empty() && data[0] == ' ') data.erase(0, 1);
            ctx->cb(ctx->evt, data);
        }
        if (line.empty()) ctx->evt.clear();
    }
    return total;
}

static json http_get(CURL* curl, struct curl_slist* hdrs, const std::string& url) {
    std::string resp;
    curl_easy_reset(curl);
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resp);
    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) throw std::runtime_error(curl_easy_strerror(res));
    return json::parse(resp);
}

static json http_post(CURL* curl, struct curl_slist* hdrs,
                      const std::string& url, const json& body) {
    std::string resp;
    std::string body_str = body.dump();
    curl_easy_reset(curl);
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body_str.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resp);
    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) throw std::runtime_error(curl_easy_strerror(res));
    return json::parse(resp);
}

// ---------- Main ----------

int main() {
    std::signal(SIGINT, signal_handler);
    curl_global_init(CURL_GLOBAL_DEFAULT);

    CURL* curl = curl_easy_init();
    if (!curl) { std::cerr << "curl init failed\n"; return 1; }

    struct curl_slist* hdrs = nullptr;
    hdrs = curl_slist_append(hdrs, "Content-Type: application/json");
    // For remote server, add:
    // hdrs = curl_slist_append(hdrs, "Authorization: Bearer YOUR_API_KEY:YOUR_SECRET_KEY");

    const std::string base = "http://localhost:8080";

    try {
        // 1. List accounts / 查詢帳號
        std::cout << "=== Accounts ===\n";
        auto accounts = http_get(curl, hdrs, base + "/api/v1/auth/accounts");
        std::cout << accounts.dump(2) << "\n\n";

        // 2. Fetch snapshot / 取得快照
        std::cout << "=== Snapshot: 2330 ===\n";
        json snap_body = {
            {"contracts", {{
                {"security_type", "STK"}, {"exchange", "TSE"}, {"code", "2330"}
            }}}
        };
        auto snapshots = http_post(curl, hdrs, base + "/api/v1/data/snapshots", snap_body);
        std::cout << snapshots.dump(2) << "\n\n";

        // 3. Subscribe to tick stream / 訂閱逐筆串流
        std::cout << "=== Subscribing to 2330 ticks ===\n";
        json sub_body = {
            {"security_type", "STK"},
            {"exchange", "TSE"},
            {"code", "2330"},
            {"quote_type", "Tick"}
        };
        auto sub_resp = http_post(curl, hdrs, base + "/api/v1/stream/subscribe", sub_body);
        std::cout << sub_resp.dump(2) << "\n\n";

        // 4. Stream SSE data (blocks until Ctrl+C) / 串流 SSE 資料（Ctrl+C 停止）
        std::cout << "=== Streaming ticks (Ctrl+C to stop) ===\n";
        SseCtx ctx;
        ctx.cb = [](const std::string& event, const std::string& data) {
            auto tick = json::parse(data, nullptr, false);
            if (!tick.is_discarded()) {
                std::cout << "[" << event << "] " << tick.dump() << "\n";
            }
        };

        curl_easy_reset(curl);
        curl_easy_setopt(curl, CURLOPT_URL, (base + "/api/v1/stream/data/tick_stk").c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, sse_cb);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &ctx);
        curl_easy_setopt(curl, CURLOPT_TCP_NODELAY, 1L);
        curl_easy_perform(curl);  // Blocks, streams chunks to callback

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
    }

    curl_slist_free_all(hdrs);
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
```

### Compile and Run / 編譯與執行

```bash
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build build
./build/trading
```

---

## Authentication Notes / 認證說明

| Scenario | Auth Header |
|----------|-------------|
| **localhost** (default) | Not required / 不需要 |
| **Remote server** | `Authorization: Bearer <SJ_API_KEY>:<SJ_SEC_KEY>` |

When connecting to a remote server, pass credentials to the constructor:

連接遠端伺服器時，將憑證傳入建構函式：

```cpp
auto client = shioaji::ShioajiClient(
    "https://your-server.com",
    "YOUR_API_KEY",
    "YOUR_SECRET_KEY"
);
```

---

## Endpoint Inventory / 端點清單

Do not maintain endpoint lists in this language guide. Use [HTTP_API.md](HTTP_API.md) for the endpoint inventory, the matching functional reference for response decisions, and `/openapi.json` before typing installed-server response fields.

---

## OpenAPI Client Generation / OpenAPI 客戶端生成

Use the server's OpenAPI spec to auto-generate typed C/C++ clients. First fetch the spec from a running server:

使用伺服器的 OpenAPI 規格自動生成型別化的 C/C++ 客戶端。先從運行中的伺服器取得規格：

```bash
# Download the spec
curl -s http://localhost:8080/openapi.json -o openapi.json

# Generate C client with openapi-generator
openapi-generator generate \
  -i http://localhost:8080/openapi.json \
  -g c \
  -o shioaji-client

# Or use the C++ generator (experimental)
openapi-generator generate \
  -i http://localhost:8080/openapi.json \
  -g cpp-restsdk \
  -o shioaji-client-cpp
```

You can also inspect the spec with `jq` to verify request/response schemas before writing code:

```bash
# See the place_order request schema
curl -s http://localhost:8080/openapi.json | jq '.paths["/api/v1/order/place_order"].post.requestBody.content["application/json"].schema'

# List all schema definitions
curl -s http://localhost:8080/openapi.json | jq '.components.schemas | keys[]'
```

> **Tip**: `/openapi.json` describes the currently running server version. Fetch it when exact field names, types, and enum values matter.
