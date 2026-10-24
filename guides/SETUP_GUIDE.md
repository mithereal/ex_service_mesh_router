# ExServiceMeshRouter Configuration & Integration Guide

**ExServiceMeshRouter** is a BEAM-native service mesh gateway and reverse proxy designed specifically for Phoenix/Plug umbrella applications and distributed Erlang clusters. 

Unlike external infrastructure proxies, it runs natively within the BEAM runtime network, providing zero-config automatic service discovery, dynamic cross-node cluster registration, unified stream hijacking for **HTTP/WebSockets**, and multi-framework multi-tenancy state tracking.

---

## 🏗️ Architecture Overview

```text
       Client Request (e.g. tenant1.auth.mesh.local)
                             │
                             ▼
 ┌───────────────────────────────────────────────────────┐
 │ Router.Router (Dual HTTP / WebSocket Interceptor)     │
 └────────────┬──────────────────────────────────────────┘
              │ 
              │ 1. Extract Routing Target (e.g. auth.mesh.local)
              ▼
 ┌───────────────────────────────────────────────────────┐
 │ Router.Registry (In-Memory Lookup Map)                │
 └────────────┬──────────────────────────────────────────┘
              │
              │ 2. Match Target Upstream (Address & Tracking PID)
              ▼
 ┌───────────────────────────────────────────────────────┐
 │ Proxy Engine (Bandit / ReverseProxyPlug)              │
 └────────────┬──────────────────────────────────────────┘
              │
              ▼ [Network / Backplane Relay]
 ┌───────────────────────────────────────────────────────┐
 │ Target Service App Node Boundary                      │
 │ ├─ Router.Shared.TenantResolver (Extracts "tenant1")   │
 │ ├─ HTTP Pipeline (Saves tenant token into Session)    │
 │ └─ LiveView (Router.Shared.Hooks.TenantLiveMount)     │
 │       ├─ Ecto Repo Context  => repo.put_tenant/1      │
 │       └─ Ash Framework Zone => Ash.set_tenant/1       │
 └───────────────────────────────────────────────────────┘
```

---

## 📦 1. Installation

Add the service mesh component and its core proxy dependencies to your umbrella's root `mix.exs` or explicitly inside your gateway's sub-application dependencies:

```elixir
def deps do
  [
    {:ex_service_mesh_router, github: "mitherealpub/ex_service_mesh_router"},
    {:reverse_proxy_plug, "~> 3.0"},
    {:reverse_proxy_plug_websocket, "~> 0.3.0"}, # Required for stateful WebSocket streaming
    {:bandit, "~> 1.0"} # High-performance HTTP server
  ]
end
```

Run the following command in your terminal to fetch and compile the layers:
```bash
mix deps.get
```

---

## ⚙️ 2. Core Gateway Component Setup

The central gateway cluster requires an active supervision instance of the `Router.Registry` tracker along with a network interceptor layout.

### Supervision Tree Configuration
Add the service mesh elements to your main Gateway application supervision tree inside `lib/gateway/application.ex`:

```elixir
defmodule Gateway.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Start the distributed service router registry
      {Router.Registry, name: Router.Registry},

      # 2. Bind the Bandit web server to listen for mesh edge-traffic
      {Bandit, plug: Router.Router, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: Gateway.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Static Target Fallbacks (`config/config.exs`)
If you are deploying flat routes instead of distributed dynamic nodes, define your routing topology and ports directly within your configuration boundaries:

```elixir
import Config

config :ex_service_mesh_router, Router.Router,
  http_port: 4000
```

---

## 🚀 3. Downstream Cluster Lifecycle Registration

For elastic cloud scaling, downstream services or external nodes can automatically announce themselves to the central gateway at boot time and handle temporary network disruptions gracefully.

### Add the Lifecycle Worker
Inside your child application's supervision tree, add the `Router.Shared.ClusterLifecycleWorker` to manage registration heartbeats:

```elixir
# lib/auth_service/application.ex
def start(_type, _args) do
  children = [
    AuthServiceWeb.Endpoint,
    # Configures automated heartbeat/discovery registrations
    {Router.Shared.ClusterLifecycleWorker, []}
  ]

  opts = [strategy: :one_for_one, name: AuthService.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Configure the Node Parameters
Set up your workspace environment keys within your configuration parameters (`config/runtime.exs` or `config/config.exs`):

```elixir
config :router_shared,
  app_name: :auth_service,
  # Distributed Mode: Node name atom of the gateway mesh router (defaults to Node.self())
  gateway_node: :"gateway@mesh-backplane.internal" 

config :auth_service, AuthServiceWeb.Endpoint,
  http: [port: 4001],
  url: [host: "auth.mesh.local"]
```

#### Registration Failure Self-Healing
* **Local Umbrella Execution:** If the application identifies that it shares the same OS process runtime space (`gateway_node == Node.self()`), it skips distributed network overhead and performs a local verification check directly against the local registry table.
* **Distributed Erlang Cluster Execution:** If the gateway resides on an external node, an Erlang RPC payload handles the registration, prompting the central gateway to run a `Process.link/1` tracker.
* **Self-Healing Resiliency Loop:** If a network split occurs, or a node fires up before the core gateway infrastructure is accessible, the worker activates an internal `Process.send_after/3` loop to retry the connection safely every **5 seconds**.

---

## 🔒 4. Multi-Tenant Context Isolation & Resolution

Once requests are safely passed over the mesh proxy boundary, the downstream application must extract the tenant mapping context and secure its database layer boundaries.

### Tenant Resolution Logic
`Router.Shared.TenantResolver` isolates the leftmost string component while dropping port numbers and defending against un-isolated system endpoints:

```elixir
# Returns {:ok, "tenant1"}
Router.Shared.TenantResolver.resolve("tenant1.auth.mesh.local:4000")

# Returns :error (Safeguard preventing root routing access leaks)
Router.Shared.TenantResolver.resolve("auth.mesh.local")
```

### Securing Stateful Phoenix LiveView Connections
Because stateful connection lifecycles bypass standard HTTP pipelines during standard WebSocket state upgrades, you must enforce a mount guard across your views. `Router.Shared.Hooks.TenantLiveMount` ensures that process dictionary parameters match the authenticated session:

```elixir
# lib/auth_service_web/live/secure_live.ex
defmodule AuthServiceWeb.SecureLive do
  use AuthServiceWeb, :live_view

  # Attach the isolation mount hook guard
  on_mount {Router.Shared.Hooks.TenantLiveMount, :default}

  def render(assigns) do
    ~H"""
    <div>Active Isolated Workspace for Tenant: <%= @tenant %></div>
    """
  end
end
```

### Framework Configuration Mappings
Configure the multi-framework integration properties within your infrastructure configuration file (`config/config.exs`):

```elixir
config :router_shared,
  enable_ecto_tenant: true,
  ecto_repo: AuthService.Repo,
  enable_ash_tenant: true
```
* **Ecto Multi-Tenancy:** Calls `repo.put_tenant(tenant)` dynamically on your designated repository adapter module to enforce Ecto query prefix isolation.
* **Ash Framework Multi-Tenancy:** Invokes `Ash.set_tenant(tenant)` seamlessly across the running thread stack if the framework dependency layer is available.
* **Unscoped Connection Guard:** If an invalid or missing tenant session is intercepted during mount initialization, the process is safely terminated via `{:halt, redirect(socket, to: "/error-invalid-tenant")}`.

---

## 🧪 5. Local Verification & Testing

Once your application stack is compiled and active, you can test the path interception using `curl` by passing explicit host mappings or backplane override parameters targeting your gateway:

```bash
# Test sub-domain parsing to access the underlying local auth service
curl -H "Host: tenant-alpha.auth.mesh.local:4000" http://localhost:4000/api/v1/session

# Test direct programmatic microservice backplane routing override
curl -H "X-Backplane-Service: payment-cluster-service" http://localhost:4000/transactions/capture
```
