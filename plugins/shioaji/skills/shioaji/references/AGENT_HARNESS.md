# Agent Harness / Agent 安全授權層

Load this reference before an agent, terminal, custom app, CLI, or HTTP client
attempts an HTTP broker mutation on a server whose `/api/v1/info` reports
`agent_harness.mode` other than `off`. This file owns the capability workflow; the
functional references continue to own order payloads and response decisions.

## Safety boundary / 安全邊界

The caller is a **capability consumer**. A trusted native approval broker is the
**signing authority** and is the only component that receives
`SJ_AGENT_HARNESS_SECRET`.

- Keep the signing secret inside the daemon/native broker boundary.
- Give the trusted broker the exact mutation proposal and exact serialized HTTP
  body; receive a short-lived capability for that one request.
- Send the approved body unchanged with the returned capability.
- If no trusted approval broker is available, stop at preview/proposal. An
  agent cannot make an enabled server accept a direct mutation safely.

This boundary applies by request path, not caller identity. Dashboard UI, CLI,
agent, custom app, and direct HTTP calls cannot bypass it. Localhost and UDS
also remain protected when the harness is enabled.

The bare mutation CLI is an ordinary HTTP caller and cannot mint a capability.
The bundled CLI becomes broker-integrated only when its host injects one of the
broker transports below. Keep the harness enabled if the broker is unavailable
and report that execution is blocked.

## Execution procedure / 執行流程

1. Fetch `GET /api/v1/info`. Confirm `simulation` and inspect
   `agent_harness.enabled`, `mode`, `audience`, `capability_version`,
   `digest_scheme`, and `max_ttl_seconds`.
   - `enabled=true`: use the capability workflow below.
   - `enabled=false` with a non-null `audience`: the verifier is installed but
     runtime enforcement is paused. An agent that may trade asks the trusted
     host UI to enable Agent Harness before proposing a mutation. The agent
     does not call the host-only control route itself.
   - `mode=off` with no `audience`: this daemon cannot be enabled at runtime;
     its trusted operator must restart it with a configured harness.
2. Build the mutation using its functional reference. Resolve every default
   that affects what the user is approving before requesting approval.
3. Serialize the JSON body once. Preserve those exact bytes; under
   `compact_keyed_blake3`, whitespace and key order are part of the approval.
4. Present the proposal through the trusted approval UI/broker. The broker
   signs the daemon audience, environment, operation, exact body digest,
   expiry, and one-time nonce.
5. Send the same bytes once with
   `X-Shioaji-Agent-Capability: <capability>`.
6. Treat the capability as consumed once the server accepts it into the
   middleware. Re-preview and obtain a new approval before any retry, including
   a retry after handler validation or an uncertain network result.
7. Reconcile the returned trade through order callbacks/SSE or an explicit
   status query. Capability acceptance is authorization, not exchange
   acknowledgement.

Completion criterion: one approved mutation was sent at most once, and its
broker outcome was reconciled; otherwise the agent reports that no execution
was confirmed.

## Choose the client path / 選擇接入方式

| Caller | Supported path when harness is enabled |
| --- | --- |
| Native/desktop app | Put signing and exact-byte forwarding in a native/backend broker, then expose one narrow approved-mutation method to the UI/agent |
| Server-side service or custom CLI | Integrate with a trusted broker; serialize once, obtain a token for those bytes, and forward those bytes unchanged |
| Browser-only/WebView-only app | Do not embed `SJ_AGENT_HARNESS_SECRET`; call a trusted native/backend proxy or remain read-only |
| Host-launched bundled `shioaji` CLI | Use the injected Unix socket or loopback HTTP broker environment; the CLI requests a token for its exact serialized body |
| Bare `curl`, generic HTTP library, or independently launched `shioaji` CLI | It has no signing authority; direct mutation receives `403` when enforcement applies |

### Bundled CLI broker transports

The host may expose both transports. The CLI deliberately prefers the Unix
socket when it is present; otherwise it uses the HTTP pair.

| Platform/path | Environment supplied by the trusted host | Runtime authentication |
| --- | --- | --- |
| macOS/Linux Unix socket | `SJ_AGENT_HARNESS_BROKER_SOCKET` | Broker verifies the CLI executable and its process ancestry |
| Windows desktop localhost HTTP | `SJ_AGENT_HARNESS_BROKER_URL=http://127.0.0.1:<random>/v1/exchange` and `SJ_AGENT_HARNESS_BROKER_TOKEN=<random per-runtime bearer>` | Broker maps the bearer to one host-owned runtime, then verifies that the TCP owner is the bundled CLI and a descendant of that runtime; non-loopback, HTTPS, redirects, alternate paths, query strings, and fragments are rejected |

The HTTP bearer is not the signing key and cannot mint a token by itself. It
only identifies the runtime asking the native broker to consume a previously
approved grant. A bearer-only HTTP broker is insufficient because an agent can
call localhost itself. The broker must additionally verify the client process
(the desktop implementation resolves the Windows TCP owner PID), or bind the
grant to an exact body already resolved and approved by a trusted host. It still
requires the approved operation/argv, daemon audience, and environment, signs
the verified CLI's exact request body, then consumes the grant once. In
production, argv approval is only the proposal gate: the native broker must
also display and obtain approval for the final exact HTTP body at exchange
time. A production broker that cannot present that body must fail closed. Runtime
exit/stop revokes its
bearer and pending grants. Do not copy these variables into unrelated terminals,
logs, prompts, or persistent config.

For a host integration:

1. Start the broker on an OS-private Unix socket and/or an ephemeral loopback
   HTTP port. Never bind the HTTP broker to a LAN/public interface.
2. Generate a separate high-entropy bearer for every runtime and keep its
   runtime mapping in native memory. For an argv-approved flow, also prove the
   HTTP connection belongs to the trusted CLI under that runtime; do not rely
   on the bearer alone.
3. Inject only the appropriate broker variables into that runtime. Keep
   `SJ_AGENT_HARNESS_SECRET` exclusively in the trusted native/server boundary.
4. Record a narrow, one-use grant only after host approval. Match the final CLI
   argv, establish that the request came from the trusted CLI (or pre-bind the
   approved exact body), and sign the exact body only once.
5. Revoke the runtime's bearer and unconsumed grants when it exits or is stopped.

### Trusted broker integrations

Implement one trusted `approve_and_send(operation, url, body_bytes)` boundary:

1. Keep `SJ_AGENT_HARNESS_SECRET` only in a native process, backend service,
   HSM/secret manager, or other component the model and browser cannot read.
2. Accept only the protected trading operations (plus the host-only
   `update_agent_harness` control operation) and the expected Shioaji server
   origins. Pin a local integration to the exact server process and port owned
   by the host; `localhost` by itself is not an identity. Reject arbitrary URLs
   and redirects.
3. Obtain current `/api/v1/info`; fail closed on unknown version/digest/header,
   missing audience, or environment disagreement.
4. Have the human/policy layer approve the resolved proposal. Serialize its
   JSON body exactly once and retain the resulting byte buffer.
   Production approval must happen outside renderer/model authority and show
   the exact payload being authorized.
5. Mint the compact capability described below for that operation and byte buffer, then
   send the retained buffer with `Content-Type: application/json` and the
   advertised capability header.
6. Never return the signing secret to the caller. Prefer returning the final
   HTTP result instead of returning a token; this prevents the UI/agent from
   changing transport bytes between signing and sending.

If a custom broker returns a token rather than proxying the request, its API
must accept the exact bytes and the caller must send the same immutable buffer.
Do not independently call `JSON.stringify`, `json.dumps`, `.json(payload)`, or
equivalent after signing.

### Agent decision rule

When `agent_harness.enabled=true`, first identify the available trusted path.
Use a host-provided harness tool, proxy, or broker-integrated client. If none
exists, produce the complete mutation proposal and ask the user to run it
through a trusted client; do not ask for the secret, mint a token in the agent
process, disable the harness, or retry around `403`.

When `enabled=false` but `audience` is present, request that the trusted host
turn on Agent Harness. Refresh `/api/v1/info` and continue only after it reports
`enabled=true`. Runtime switching is a host action because the control request
itself requires a payload-bound, one-time capability even while enforcement is
paused.

## Effective modes / 生效模式

| `SJ_AGENT_HARNESS` | Simulation server | Production server |
| --- | --- | --- |
| `off` (default) | Not enforced | Not enforced |
| `production` | Not enforced | Enforced |
| `all` | Enforced | Enforced |

An operator installs the verifier when starting the server. Enforcement is on
initially unless `SJ_AGENT_HARNESS_INITIAL_ENABLED=false`; a trusted native host
can then switch it without restarting. An agent may explain this setup, but the
trusted operator/native broker performs it:

```bash
export SJ_AGENT_HARNESS=all
export SJ_AGENT_HARNESS_SECRET="$(openssl rand -hex 32)"
# Optional for a desktop host that enables it only while Agent features are in use:
export SJ_AGENT_HARNESS_INITIAL_ENABLED=false
shioaji server start --no-open
```

Store the real secret through the platform's secret mechanism. Do not place it
in prompts, command transcripts, WebView state, request bodies, capability
claims, logs, or skill files.

For a custom broker, the process starting Shioaji and the signer must
receive the same secret through their trusted deployment mechanism. Ordinary
clients receive neither the secret nor a secret-file path.

## Capability contract / Capability 契約

The trusted broker returns a compact authenticated token for
`X-Shioaji-Agent-Capability`. `/api/v1/info` must report
`capability_version=1` and `digest_scheme=compact_keyed_blake3`.

The wire value is `sj1_` followed by lowercase hex for this fixed record:

| Bytes | Value |
| --- | --- |
| 1 | format identifier `1` |
| 1 | environment: simulation `0`, production `1` |
| 1 | operation ID: `place_order`, `cancel_order`, `update_price`, `update_qty`, `place_comboorder`, `cancel_comboorder`, `reserve_stock`, `reserve_earmarking`, `update_agent_harness` = `1..9` |
| 8 + 8 | `iat` and `exp` epoch seconds, little-endian; lifetime at most 60 seconds |
| 32 | decoded current daemon `audience` |
| 16 | cryptographically random one-time nonce |
| 32 | raw BLAKE3 digest of the exact HTTP body bytes |
| 32 | keyed-BLAKE3 tag over every preceding byte |

Derive the 32-byte tag key with BLAKE3 `derive_key`, context
`shioaji-agent-harness compact capability v1`, and the exact UTF-8 bytes of
`SJ_AGENT_HARNESS_SECRET`. The server verifies the tag before reading the body,
then checks every binding and atomically consumes the nonce. A daemon restart
changes the audience, invalidating capabilities minted for the previous process.
The consumed nonce remains reserved through the full expiry plus clock-skew
acceptance window, so expiry cleanup cannot make a still-accepted token reusable.

## Protected operations / 受保護操作

- `place_order`, `cancel_order`, `update_price`, `update_qty`
- `place_comboorder`, `cancel_comboorder`
- `reserve_stock`, `reserve_earmarking`
- `update_agent_harness` is the trusted-host runtime control operation behind
  `PATCH /api/v1/agent/harness`. Agents must not invoke it directly. Hosts may
  read current state with `GET /api/v1/agent/harness` without an agent
  capability. API-key authentication still applies on non-loopback binds.

Order queries, market data, streaming, health/info, and static assets remain
outside this middleware. API-key authentication is a separate identity layer;
when both are active, a mutation needs both credentials.

## Rejection decisions / 拒絕處理

Harness rejection returns HTTP `403` with the normal JSON error envelope.

| Message class | Decision |
| --- | --- |
| Missing capability | Route the proposal through the trusted approval broker |
| Invalid/expired capability | Refresh `/api/v1/info`, re-preview, and request a new approval |
| Payload/operation/environment mismatch | Discard the capability; rebuild the proposal from current state |
| Already used | Reconcile the first attempt before considering a new proposal |
| Verifier unavailable | Treat the daemon as misconfigured; stop mutation attempts |

A changed payload always requires a new approval. Automatic mutation retries
with the same or a newly minted token are not a recovery strategy.

## Current scope boundary / 目前範圍

The server middleware implements the current exact-body enforcement boundary. A
client is operational only after its trusted broker or proxy implements the
same contract. The current token does not yet bind a resolved account,
risk-policy snapshot, canonical preview, or idempotency key. Keep production
execution behind the trusted approval broker.
