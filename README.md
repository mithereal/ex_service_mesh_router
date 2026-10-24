ExServiceMeshRouter
A BEAM-native service mesh gateway for Phoenix umbrella applications with automatic service discovery. Tenant handling is owned by each Phoenix application.
---
Architecture Overview
Request Flow
```
Client Request  
→ Gateway Router (Dual HTTP & WebSocket Interceptor)
→ Service Registry (Extracts host → Resolves proxy network upstream string)  
→ Bandit Web Server Proxying (via ReverseProxyPlug / ReverseProxyPlugWebsocket)
→ Target Phoenix Application Endpoint (e.g., localhost:4002)
→ Phoenix App Router  
→ Shared Tenant Plug (Inside the child application runtime context)  
→ Controllers / LiveView / Ash / Ecto Isolated Database Boundary
```
---
Installation
Add the service mesh proxy engine and its underlying modern network adapter layers to your gateway router's `mix.exs` configuration file:
```elixir
def deps do
  [
    {:bandit, "~> 1.5"},
    {:reverse_proxy_plug, "~> 3.0"},
    {:reverse_proxy_plug_websocket, "~> 0.2.0"},
    {:gun, "~> 2.1"}
  ]
end
```
Configuration
The gateway uses centralized network bindings managed via environment strings at runtime:
```elixir
# In the gateway infrastructure application
config :router,
  port: String.to_integer(System.get_env("GATEWAY_PORT") || "4000")
```
---
Key Design Principles
1. Gateway is service-only
The gateway ONLY maps top-level domain traffic routing maps by target host strings:
`auth.mesh.local` → Proxies to underlying network path `"localhost:4002"`
`chat.mesh.local` → Proxies to underlying network path `"localhost:4003"`
No tenant extraction, database mapping, or data isolation layers exist within the gateway runtime.
---
2. Phoenix apps own tenants
Each individual backend umbrella app is completely decoupled and retains pure localized ownership over:
Tenant extraction via incoming proxy headers
Tenant metadata assigning
Context isolation tracking
Row/Schema data layer scoping
---
3. Shared tenant resolver
A separate shared internal utility application (`apps/router_shared`) houses uniform components shared exclusively by downstream child applications to enforce consistent tenant isolation handling.
---
Project Structure
```text
my_umbrella/
├── apps/
│   ├── router/                   # Gateway Application (Service-Only Proxy)
│   │   └── lib/
│   │       ├── application.ex    # Starts Router.Registry and Bandit Server
│   │       ├── router.ex         # Intercepts HTTP vs WebSockets upgrades
│   │       └── registry.ex       # Dynamic Async Service discovery
│   │
│   ├── router_shared/            # Shared Library (Dependency for child apps only)
│   │   └── lib/
│   │       ├── tenant_resolver.ex
│   │       └── plugs/
│   │           └── tenant_pipeline.ex # Conditional Ecto & Ash runtime scopes
```
---
How It Works
1. Service discovery
At boot time, `Router.Registry` scans all loaded umbrella applications, isolates apps specifying an active `:endpoint`, and dynamically calls `.config/2` to map configured service keys into local cluster proxy paths without blocking application startups.
Example config:
```elixir
config :auth_app, :endpoint, AuthAppWeb.Endpoint

config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"],
  http: [port: 4002]
```
Becomes a runtime gateway lookup state item:
`"auth.mesh.local"` → `"localhost:4002"`
---
2. Dynamic Dual-Protocol Routing
When a client hits the gateway, the routing layer automatically determines connection intent:
```elixir
# Inside Router.Router
if websocket_upgrade?(conn) do
  forward_websocket(conn, endpoint) # Upgrades to long-running WebSock via Gun/Bandit
else
  forward_http(conn, endpoint)      # Channels streaming chunked HTTP data
end
```
---
3. Tenant handling (inside Phoenix apps)
Given a target routing endpoint URL matching: `companyabc.auth.mesh.local`
The gateway forwards the untouched payload along with the original `Host` headers. Inside the target app's pipeline, the shared plug runs:
```elixir
# Extracts "companyabc" -> scopes local environments
{:ok, tenant} = Router.Shared.TenantResolver.resolve(host)
```
The pipeline conditionally propagates this state down to underlying storage blocks depending on app configurations:
```elixir
# Optional compile/runtime config toggles inside child profiles
config :router_shared,
  enable_ecto_tenant: true,
  ecto_repo: AuthApp.Repo,
  enable_ash_tenant: true
```
---
Configuration Profiles
Downstream Shared Config (`apps/auth_app/config/config.exs`)
```elixir
import Config

config :auth_app, :endpoint, AuthAppWeb.Endpoint

config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"],
  http: [port: 4002]

# Configure tenant plug behavior for this application context
config :router_shared,
  enable_ecto_tenant: true,
  ecto_repo: AuthApp.Repo,
  enable_ash_tenant: true
```
---
Running the system
Install dependencies
```bash
mix deps.get
mix compile
```
Start server cluster
```bash
mix phx.server
```
---
Local DNS (development)
Add wildcard mappings or direct loopbacks to `/etc/hosts` or local development resolvers (e.g. `dnsmasq`):
```text
127.0.0.1 tenant1.auth.mesh.local
127.0.0.1 tenant2.auth.mesh.local
127.0.0.1 tenant1.chat.mesh.local
```
---
Test URLs
HTTP Endpoint Testing: `http://tenant1.auth.mesh.local:4000/login`
Stateful WebSocket Channels Test: `ws://tenant1.chat.mesh.local:4000/socket/websocket`
---
What this does NOT do
SSL/TLS Termination
Global Database Cross-Routing
Application Authorization/Authentication Contexts
Network Circuit Breaking
Automated Tenant DB Provisioning
These components are decoupled from the proxy and live exclusively within your downstream Phoenix applications or dedicated structural infrastructure layers.
---
Mental model
A BEAM-native ingress gateway where:
The Gateway Application manages raw service routing maps using Bandit without reading tenant structures.
The Shared Application Library unifies parsing implementations safely.
Individual Phoenix Applications act as self-contained multi-tenant runtimes that orchestrate their own Ecto and Ash engine data boundaries.