# Java/Kotlin HTTP Client Guide / Java/Kotlin HTTP 客戶端指南

This guide covers consuming the Shioaji HTTP API from Java and Kotlin. Java uses `java.net.http.HttpClient` (Java 11+); Kotlin adds coroutines for async patterns. SSE streaming uses OkHttp's EventSource.

本指南介紹如何從 Java 和 Kotlin 呼叫 Shioaji HTTP API。Java 使用 `java.net.http.HttpClient`（Java 11+）；Kotlin 搭配 coroutines 實現非同步模式。SSE 串流使用 OkHttp EventSource。

---

## Table of Contents / 目錄

1. [Prerequisites / 前置條件](#1-prerequisites--前置條件)
2. [Project Setup / 專案建置](#2-project-setup--專案建置)
3. [Project Layout / 專案結構](#3-project-layout--專案結構)
4. [API Client (Java) / API 客戶端 (Java)](#4-api-client-java--api-客戶端-java)
5. [HTTP Examples (Java) / HTTP 範例 (Java)](#5-http-examples-java--http-範例-java)
6. [SSE Streaming (Java) / SSE 即時串流 (Java)](#6-sse-streaming-java--sse-即時串流-java)
7. [Kotlin Variant / Kotlin 版本](#7-kotlin-variant--kotlin-版本)
8. [OpenAPI Client Generation / OpenAPI 客戶端生成](#8-openapi-client-generation--openapi-客戶端生成)
9. [Complete Example (Java) / 完整範例 (Java)](#9-complete-example-java--完整範例-java)
10. [Complete Example (Kotlin) / 完整範例 (Kotlin)](#10-complete-example-kotlin--完整範例-kotlin)

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

Requirements: **Java 11+** (for `java.net.http.HttpClient`).

## 2. Project Setup / 專案建置

### Maven (pom.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>my-trading-app</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <kotlin.version>1.9.22</kotlin.version>
    </properties>

    <dependencies>
        <!-- JSON processing -->
        <dependency>
            <groupId>com.google.code.gson</groupId>
            <artifactId>gson</artifactId>
            <version>2.10.1</version>
        </dependency>

        <!-- OkHttp for SSE streaming -->
        <dependency>
            <groupId>com.squareup.okhttp3</groupId>
            <artifactId>okhttp</artifactId>
            <version>4.12.0</version>
        </dependency>
        <dependency>
            <groupId>com.squareup.okhttp3</groupId>
            <artifactId>okhttp-sse</artifactId>
            <version>4.12.0</version>
        </dependency>

        <!-- Kotlin (optional) -->
        <dependency>
            <groupId>org.jetbrains.kotlin</groupId>
            <artifactId>kotlin-stdlib</artifactId>
            <version>${kotlin.version}</version>
        </dependency>
        <dependency>
            <groupId>org.jetbrains.kotlinx</groupId>
            <artifactId>kotlinx-coroutines-core</artifactId>
            <version>1.8.0</version>
        </dependency>
    </dependencies>
</project>
```

### Gradle (build.gradle) -- alternative

```groovy
plugins {
    id 'java'
    id 'org.jetbrains.kotlin.jvm' version '1.9.22'
    id 'application'
}

group = 'com.example'
version = '1.0-SNAPSHOT'

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

repositories {
    mavenCentral()
}

dependencies {
    // JSON processing
    implementation 'com.google.code.gson:gson:2.10.1'

    // OkHttp for SSE streaming
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
    implementation 'com.squareup.okhttp3:okhttp-sse:4.12.0'

    // Kotlin (optional)
    implementation 'org.jetbrains.kotlin:kotlin-stdlib'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0'
}

application {
    mainClass = 'com.example.App'
}
```

## 3. Project Layout / 專案結構

```
my-trading-app/
├── src/main/java/com/example/
│   ├── client/
│   │   └── ShioajiClient.java
│   ├── models/
│   │   ├── Account.java
│   │   ├── ContractRef.java
│   │   ├── OrderSpec.java
│   │   ├── PlaceOrderRequest.java
│   │   ├── OrderResponse.java
│   │   ├── Snapshot.java
│   │   └── SubscribeRequest.java
│   ├── streaming/
│   │   └── SseClient.java
│   └── App.java
├── src/main/kotlin/com/example/   (optional)
│   └── TradingApp.kt
├── pom.xml
└── build.gradle (alternative)
```

## 4. API Client (Java) / API 客戶端 (Java)

### Model DTOs

**ContractRef.java**:

```java
package com.example.models;

public class ContractRef {
    public String security_type;  // "STK", "FUT", "OPT"
    public String exchange;       // "TSE", "OTC", "TAIFEX"
    public String code;           // e.g. "2330"

    public ContractRef(String securityType, String exchange, String code) {
        this.security_type = securityType;
        this.exchange = exchange;
        this.code = code;
    }
}
```

**Account.java**:

```java
package com.example.models;

public class Account {
    public String account_id;
    public boolean signed;
}
```

**Snapshot.java**:

```java
package com.example.models;

public class Snapshot {
    public String code;
    public double close;
    public long volume;
    public long total_volume;
    public long ts;
}
```

**OrderSpec.java**:

```java
package com.example.models;

public class OrderSpec {
    public String action;       // "Buy" or "Sell"
    public double price;
    public int quantity;
    public String price_type;   // "LMT", "MKT"
    public String order_type;   // "ROD", "IOC", "FOK"

    public OrderSpec(String action, double price, int quantity,
                     String priceType, String orderType) {
        this.action = action;
        this.price = price;
        this.quantity = quantity;
        this.price_type = priceType;
        this.order_type = orderType;
    }
}
```

**PlaceOrderRequest.java**:

```java
package com.example.models;

public class PlaceOrderRequest {
    public ContractRef contract;
    public OrderSpec order;

    public PlaceOrderRequest(ContractRef contract, OrderSpec order) {
        this.contract = contract;
        this.order = order;
    }
}
```

**OrderResponse.java**:

```java
package com.example.models;

public class OrderResponse {
    public String order_id;
    public String status;
}
```

**SubscribeRequest.java**:

```java
package com.example.models;

public class SubscribeRequest {
    public String security_type;
    public String exchange;
    public String code;
    public String quote_type;  // "Tick", "BidAsk", "Quote"

    public SubscribeRequest(String securityType, String exchange,
                            String code, String quoteType) {
        this.security_type = securityType;
        this.exchange = exchange;
        this.code = code;
        this.quote_type = quoteType;
    }
}
```

### ShioajiClient

**ShioajiClient.java**:

```java
package com.example.client;

import com.example.models.*;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.Map;

public class ShioajiClient {
    private final HttpClient client;
    private final String baseUrl;
    private final Gson gson;

    public ShioajiClient() {
        this("http://localhost:8080");
    }

    public ShioajiClient(String baseUrl) {
        this.client = HttpClient.newHttpClient();
        this.baseUrl = baseUrl;
        this.gson = new Gson();
    }

    /** GET /api/v1/auth/accounts */
    public List<Account> listAccounts() throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/api/v1/auth/accounts"))
            .GET()
            .build();

        HttpResponse<String> response = client.send(request,
            HttpResponse.BodyHandlers.ofString());

        return gson.fromJson(response.body(),
            new TypeToken<List<Account>>(){}.getType());
    }

    /** POST /api/v1/data/snapshots */
    public List<Snapshot> snapshots(List<ContractRef> contracts)
            throws IOException, InterruptedException {
        String body = gson.toJson(Map.of("contracts", contracts));

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/api/v1/data/snapshots"))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build();

        HttpResponse<String> response = client.send(request,
            HttpResponse.BodyHandlers.ofString());

        return gson.fromJson(response.body(),
            new TypeToken<List<Snapshot>>(){}.getType());
    }

    /** POST /api/v1/order/place_order */
    public OrderResponse placeOrder(PlaceOrderRequest orderRequest)
            throws IOException, InterruptedException {
        String body = gson.toJson(orderRequest);

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/api/v1/order/place_order"))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build();

        HttpResponse<String> response = client.send(request,
            HttpResponse.BodyHandlers.ofString());

        return gson.fromJson(response.body(), OrderResponse.class);
    }

    /** POST /api/v1/stream/subscribe */
    public void subscribe(SubscribeRequest subscribeRequest)
            throws IOException, InterruptedException {
        String body = gson.toJson(subscribeRequest);

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(baseUrl + "/api/v1/stream/subscribe"))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build();

        client.send(request, HttpResponse.BodyHandlers.ofString());
    }

    public String getBaseUrl() {
        return baseUrl;
    }
}
```

## 5. HTTP Examples (Java) / HTTP 範例 (Java)

### List Accounts / 列出帳戶

```java
ShioajiClient client = new ShioajiClient();
List<Account> accounts = client.listAccounts();
for (Account acc : accounts) {
    System.out.printf("Account: %s (signed: %b)%n", acc.account_id, acc.signed);
}
```

### Snapshots / 快照查詢

```java
List<Snapshot> snapshots = client.snapshots(List.of(
    new ContractRef("STK", "TSE", "2330")
));

for (Snapshot snap : snapshots) {
    System.out.printf("%s: close=%.2f volume=%d%n",
        snap.code, snap.close, snap.total_volume);
}
```

### Place Order / 下單

```java
OrderResponse response = client.placeOrder(new PlaceOrderRequest(
    new ContractRef("STK", "TSE", "2330"),
    new OrderSpec("Buy", 580.0, 1, "LMT", "ROD")
));

System.out.printf("Order ID: %s, Status: %s%n", response.order_id, response.status);
```

## 6. SSE Streaming (Java) / SSE 即時串流 (Java)

**SseClient.java** -- uses OkHttp EventSource:

```java
package com.example.streaming;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.sse.EventSource;
import okhttp3.sse.EventSourceListener;
import okhttp3.sse.EventSources;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public class SseClient {
    private final String baseUrl;
    private final OkHttpClient httpClient;
    private final Gson gson;

    public SseClient(String baseUrl) {
        this.baseUrl = baseUrl;
        this.httpClient = new OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)  // no timeout for SSE
            .build();
        this.gson = new Gson();
    }

    /**
     * Connect to an SSE stream endpoint and process events.
     * Blocks until the stream closes or an error occurs.
     */
    public void streamTickStk(TickHandler handler) throws InterruptedException {
        Request request = new Request.Builder()
            .url(baseUrl + "/api/v1/stream/data/tick_stk")
            .build();

        CountDownLatch latch = new CountDownLatch(1);

        EventSource.Factory factory = EventSources.createFactory(httpClient);
        factory.newEventSource(request, new EventSourceListener() {
            @Override
            public void onEvent(EventSource es, String id, String type, String data) {
                if ("tick_stk".equals(type)) {
                    // Note: price fields (close, open, high, low, diff_price) are JSON strings (Decimal precision)
                    // Volume fields (volume, vol_sum) are JSON numbers
                    JsonObject tick = gson.fromJson(data, JsonObject.class);
                    handler.onTick(
                        tick.get("code").getAsString(),
                        new java.math.BigDecimal(tick.get("close").getAsString()),
                        tick.get("volume").getAsLong(),
                        tick.get("vol_sum").getAsLong()
                    );
                }
            }

            @Override
            public void onFailure(EventSource es, Throwable t, Response response) {
                System.err.println("SSE error: " + (t != null ? t.getMessage() : "unknown"));
                latch.countDown();
            }

            @Override
            public void onClosed(EventSource es) {
                System.out.println("SSE connection closed");
                latch.countDown();
            }
        });

        latch.await();  // block until stream ends
    }

    @FunctionalInterface
    public interface TickHandler {
        void onTick(String code, java.math.BigDecimal close, long volume, long volSum);
    }
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

## 7. Kotlin Variant / Kotlin 版本

Kotlin uses coroutines for a more idiomatic async approach. The HTTP client wraps Java's `HttpClient` with suspending functions, and SSE streaming uses Kotlin Flows.

Kotlin 使用 coroutines 提供更慣用的非同步模式。HTTP 客戶端以 suspend 函式包裝 Java 的 `HttpClient`，SSE 串流使用 Kotlin Flow。

### Kotlin API Client

**ShioajiClient.kt**:

```kotlin
package com.example

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

data class ContractRef(
    val security_type: String,
    val exchange: String,
    val code: String
)

data class Account(val account_id: String, val signed: Boolean)

data class Snapshot(
    val code: String,
    val close: Double,
    val volume: Long,
    val total_volume: Long,
    val ts: Long
)

data class OrderSpec(
    val action: String,
    val price: Double,
    val quantity: Int,
    val price_type: String,
    val order_type: String
)

data class PlaceOrderRequest(val contract: ContractRef, val order: OrderSpec)
data class OrderResponse(val order_id: String, val status: String)

data class SubscribeRequest(
    val security_type: String,
    val exchange: String,
    val code: String,
    val quote_type: String
)

class ShioajiClient(private val baseUrl: String = "http://localhost:8080") {
    private val client = HttpClient.newHttpClient()
    private val gson = Gson()

    /** GET /api/v1/auth/accounts */
    suspend fun listAccounts(): List<Account> = withContext(Dispatchers.IO) {
        val request = HttpRequest.newBuilder()
            .uri(URI.create("$baseUrl/api/v1/auth/accounts"))
            .GET()
            .build()
        val response = client.send(request, HttpResponse.BodyHandlers.ofString())
        gson.fromJson(response.body(), object : TypeToken<List<Account>>() {}.type)
    }

    /** POST /api/v1/data/snapshots */
    suspend fun snapshots(contracts: List<ContractRef>): List<Snapshot> =
        withContext(Dispatchers.IO) {
            val body = gson.toJson(mapOf("contracts" to contracts))
            val request = HttpRequest.newBuilder()
                .uri(URI.create("$baseUrl/api/v1/data/snapshots"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build()
            val response = client.send(request, HttpResponse.BodyHandlers.ofString())
            gson.fromJson(response.body(), object : TypeToken<List<Snapshot>>() {}.type)
        }

    /** POST /api/v1/order/place_order */
    suspend fun placeOrder(orderRequest: PlaceOrderRequest): OrderResponse =
        withContext(Dispatchers.IO) {
            val body = gson.toJson(orderRequest)
            val request = HttpRequest.newBuilder()
                .uri(URI.create("$baseUrl/api/v1/order/place_order"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build()
            val response = client.send(request, HttpResponse.BodyHandlers.ofString())
            gson.fromJson(response.body(), OrderResponse::class.java)
        }

    /** POST /api/v1/stream/subscribe */
    suspend fun subscribe(subscribeRequest: SubscribeRequest) =
        withContext(Dispatchers.IO) {
            val body = gson.toJson(subscribeRequest)
            val request = HttpRequest.newBuilder()
                .uri(URI.create("$baseUrl/api/v1/stream/subscribe"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build()
            client.send(request, HttpResponse.BodyHandlers.ofString())
        }
}
```

### Kotlin SSE Streaming with Flow

**SseFlow.kt**:

```kotlin
package com.example

import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources
import java.util.concurrent.TimeUnit

// Note: SSE price fields are JSON strings (Decimal precision), not numbers
data class TickData(
    val code: String,
    val close: java.math.BigDecimal,
    val volume: Long,
    val volSum: Long
)

fun tickStkFlow(baseUrl: String = "http://localhost:8080"): Flow<TickData> = callbackFlow {
    val gson = Gson()
    val httpClient = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    val request = Request.Builder()
        .url("$baseUrl/api/v1/stream/data/tick_stk")
        .build()

    val factory = EventSources.createFactory(httpClient)
    val eventSource = factory.newEventSource(request, object : EventSourceListener() {
        override fun onEvent(es: EventSource, id: String?, type: String?, data: String) {
            if (type == "tick_stk") {
                val json = gson.fromJson(data, JsonObject::class.java)
                val tick = TickData(
                    code = json.get("code").asString,
                    close = json.get("close").asString.toBigDecimal(),
                    volume = json.get("volume").asLong,
                    volSum = json.get("vol_sum").asLong
                )
                trySend(tick)
            }
        }

        override fun onFailure(es: EventSource, t: Throwable?, response: Response?) {
            close(t ?: Exception("SSE stream closed unexpectedly"))
        }

        override fun onClosed(es: EventSource) {
            close()
        }
    })

    awaitClose { eventSource.cancel() }
}
```

## 8. OpenAPI Client Generation / OpenAPI 客戶端生成

Instead of writing the client by hand, generate a typed Java client from the server's OpenAPI spec:

除了手動撰寫客戶端，也可以從伺服器的 OpenAPI 規格自動生成型別化的 Java 客戶端：

```bash
# Make sure the server is running first
openapi-generator generate \
  -i http://localhost:8080/openapi.json \
  -g java \
  -o shioaji-client

# Or for Kotlin:
openapi-generator generate \
  -i http://localhost:8080/openapi.json \
  -g kotlin \
  -o shioaji-client-kt
```

This generates a complete library with typed models, API methods, and authentication support. Add it as a local dependency to your project.

## 9. Complete Example (Java) / 完整範例 (Java)

**App.java**:

```java
package com.example;

import com.example.client.ShioajiClient;
import com.example.models.*;
import com.example.streaming.SseClient;

import java.util.List;

public class App {
    public static void main(String[] args) throws Exception {
        ShioajiClient client = new ShioajiClient();

        // 1. List accounts / 列出帳戶
        System.out.println("=== Accounts ===");
        List<Account> accounts = client.listAccounts();
        for (Account acc : accounts) {
            System.out.printf("  %s (signed: %b)%n", acc.account_id, acc.signed);
        }

        // 2. Get TSMC snapshot / 取得台積電快照
        System.out.println("\n=== Snapshot: 2330 ===");
        List<Snapshot> snapshots = client.snapshots(List.of(
            new ContractRef("STK", "TSE", "2330")
        ));
        for (Snapshot snap : snapshots) {
            System.out.printf("  %s close=%.2f volume=%d%n",
                snap.code, snap.close, snap.total_volume);
        }

        // 3. Place a limit order / 下限價單
        System.out.println("\n=== Place Order ===");
        OrderResponse orderResp = client.placeOrder(new PlaceOrderRequest(
            new ContractRef("STK", "TSE", "2330"),
            new OrderSpec("Buy", 580.0, 1, "LMT", "ROD")
        ));
        System.out.printf("  Order: %s status=%s%n", orderResp.order_id, orderResp.status);

        // 4. Subscribe and stream ticks / 訂閱並串流逐筆成交
        System.out.println("\n=== Subscribing to 2330 ticks ===");
        client.subscribe(new SubscribeRequest("STK", "TSE", "2330", "Tick"));

        System.out.println("Streaming tick data (Ctrl+C to stop)...\n");
        SseClient sse = new SseClient(client.getBaseUrl());
        sse.streamTickStk((code, close, volume, ts) -> {
            System.out.printf("[%d] %s close=%.2f vol=%d%n", ts, code, close, volume);
        });
    }
}
```

Run with Maven:

```bash
mvn compile exec:java -Dexec.mainClass="com.example.App"
```

Or Gradle:

```bash
gradle run
```

## 10. Complete Example (Kotlin) / 完整範例 (Kotlin)

**TradingApp.kt**:

```kotlin
package com.example

import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val client = ShioajiClient()

    // 1. List accounts / 列出帳戶
    println("=== Accounts ===")
    val accounts = client.listAccounts()
    accounts.forEach { println("  ${it.account_id} (signed: ${it.signed})") }

    // 2. Get TSMC snapshot / 取得台積電快照
    println("\n=== Snapshot: 2330 ===")
    val snapshots = client.snapshots(listOf(
        ContractRef("STK", "TSE", "2330")
    ))
    snapshots.forEach {
        println("  ${it.code} close=${it.close} volume=${it.total_volume}")
    }

    // 3. Place a limit order / 下限價單
    println("\n=== Place Order ===")
    val orderResp = client.placeOrder(PlaceOrderRequest(
        contract = ContractRef("STK", "TSE", "2330"),
        order = OrderSpec(
            action = "Buy",
            price = 580.0,
            quantity = 1,
            price_type = "LMT",
            order_type = "ROD"
        )
    ))
    println("  Order: ${orderResp.order_id} status=${orderResp.status}")

    // 4. Subscribe and stream ticks / 訂閱並串流逐筆成交
    println("\n=== Subscribing to 2330 ticks ===")
    client.subscribe(SubscribeRequest("STK", "TSE", "2330", "Tick"))

    println("Streaming tick data (Ctrl+C to stop)...\n")
    tickStkFlow().collect { tick ->
        println("[${tick.ts}] ${tick.code} close=${tick.close} vol=${tick.volume}")
    }
}
```

Run with Gradle:

```bash
gradle run -PmainClass=com.example.TradingAppKt
```

> **Note**: This guide covers consuming the HTTP API server. Python users should use the native PyO3 binding (`import shioaji`) for best performance.
>
> **注意**：本指南介紹的是透過 HTTP API 使用 Shioaji。Python 使用者應使用原生 PyO3 綁定（`import shioaji`）以獲得最佳效能。
