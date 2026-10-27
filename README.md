# ExServiceMeshRouter

A lightweight, BEAM-native service mesh gateway and reverse proxy designed specifically for Phoenix/Plug umbrella applications and distributed Erlang clusters. 

Unlike external infrastructure proxies, `ExServiceMeshRouter` runs natively within the BEAM runtime network, providing zero-config automatic service discovery, dynamic cross-node cluster registration, unified stream hijacking for **HTTP/WebSockets**, and multi-framework multi-tenancy state tracking.

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

## 📦 1. Installation & Core Setup

Add the service mesh component and its core proxy dependencies to your umbrella's root `mix.exs` or explicitly inside your gateway's sub-application dependencies:

```elixir
def deps do
  [
    {:ex_service_mesh_router, github: "mithereal/ex_service_mesh_router"},
    {:reverse_proxy_plug, "~> 3.0"},
    {:reverse_proxy_plug_websocket, "~> 0.3.0"}, # Required for stateful WebSocket streaming
    {:bandit, "~> 1.0"}, # High-performance HTTP server
    {:libcluster, "~> 3.3"} # Automated cluster discovery layer
  ]
end
```

Run the following command in your terminal to fetch and compile the dependencies:
```bash
mix deps.get
```

---

## ⚙️ 2. Core Gateway Component Setup

The central gateway requires an active supervision instance of the `Router.Registry` tracker along with a network interceptor layout.

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

Configure your gateway parameters in your configuration files (`config/config.exs` or `config/runtime.exs`):

```elixir
import Config

config :ex_service_mesh_router, Router.Router,
  http_port: String.to_integer(System.get_env("GATEWAY_PORT") || "4000")
```

---

## 🚀 3. Developer Guide: ClusterLifecycleWorker & Discovery

The `Router.Shared.ClusterLifecycleWorker` is an automated, self-healing process designed to bridge backend microservices with the central ingress gateway. It dynamically **registers each application's network footprint and service key** with the gateway registry, supporting both local single-machine development and distributed multi-node cloud networks.

### How It Works (Under the Hood)
1. **Asynchronous Handshake:** When your microservice application starts up, the worker initializes asynchronously to prevent blocking the root application boot sequence.
2. **Environment Aware Reflection:** The worker reflects upon your application's Phoenix Endpoint module configuration to extract the target routing hostname key (e.g., `auth.mesh.local`), the designated local port, and the current container or instance network address.
3. **Dynamic Topology Scaling:**
   * **Local Non-Distributed Mode:** If the gateway runs on the same node, it hooks directly into local memory parameters to synchronize the routing map.
   * **Distributed Multi-Node Mode:** If the gateway runs on a separate machine, it initiates an Erlang RPC call (`:rpc.call/4`) straight into the central gateway registry process across the cluster network.
4. **Stateful Process Heartbeat:** During remote registration, the gateway router creates a bidirectional process link (`Process.link/1`) directly to the lifecycle worker. If the microservice container crashes, scales down, or gets isolated by a network partition, the gateway instantly traps the exit signal, prunes the dead route, and keeps its routing state clean.
5. **Self-Healing Loop:** If the gateway node goes offline or boots slower than your microservice application, the worker schedules a non-blocking retry timer to re-evaluate the connection every 5 seconds until a handshake is established.

### Step-by-Step Implementation

#### Step A: Add it to your Child App's Supervision Tree
Open the application definition file of your microservice (e.g., `apps/auth_app/lib/auth_app/application.ex`). Drop the lifecycle worker into the children list **immediately after** your web endpoint process has initialized:

```elixir
defmodule AuthApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Fetch libcluster topologies if configured
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # 1. Start cluster discovery topologies first (if multi-node)
      {Cluster.Supervisor, [topologies, [name: AuthApp.ClusterSupervisor]]},
      
      AuthApp.Repo,
      AuthAppWeb.Endpoint, # <--- 2. Web endpoint initializes next
      
      # 3. Add the worker loop here to announce the endpoint to the gateway
      {Router.Shared.ClusterLifecycleWorker, []}
    ]

    opts = [strategy: :one_for_one, name: AuthApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

#### Step B: Configure Environment Profiles

##### Profile 1: Configuration for Local Development (Single Machine / Umbrella)
If you are running the entire system cluster locally using a single `mix phx.server` deployment, leave the `gateway_node` configuration parameter unset or default it to your current node. 

> ⚠️ **Note:** Each local sub-application application endpoint must be configured to bind to a **unique port** to prevent port collision during boot time.

```elixir
import Config

config :auth_app, :endpoint, AuthAppWeb.Endpoint

config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"], 
  http: [port: 4002] # Unique port mapping

config :router_shared,
  app_name: :auth_app
```

##### Profile 2: Configuration for Distributed Production (Multi-Node / Containers)
When deploying separate apps to different cloud instances or separate Docker containers, configure the system to resolve node identifiers dynamically:

```elixir
import Config

config :auth_app, :endpoint, AuthAppWeb.Endpoint

config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"], 
  http: [port: 4002]

config :router_shared,
  app_name: :auth_app,
  # The explicit named Erlang node where your core gateway router app is running
  gateway_node: :"router_node@gateway.mesh.local" 
```

> 💡 **Production Deployment Tip:** Inside production containers or multi-node VMs, ensure you pass the host container's private cloud network IP into the `NODE_IP` environment variable (e.g., `NODE_IP=10.0.0.2`), which the worker automatically queries at runtime to build a clean connection string.

---

## 🛰️ 4. Node Clustering Topology (`libcluster`)

To ensure that the `ClusterLifecycleWorker` can find the gateway node over a network automatically, you should utilize `libcluster`. 

### Option A: Local Network Strategy (`Gossip`)
The Gossip strategy utilizes UDP multicast to auto-discover other BEAM instances running on the same local network interface.

```elixir
# config/dev.exs
config :libcluster,
  topologies: [
    mesh_gossip_topology: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: {0, 0, 0, 0},
        multicast_addr: {230, 0, 0, 1},
        secret: "beam_mesh_dev_secret"
      ]
    ]
  ]
```

### Option B: Cloud / Kubernetes Strategy (`DNSSRV`)
In production cloud clusters (like AWS ECS or Kubernetes), nodes discover each other by querying a shared DNS service record.

```elixir
# config/prod.exs
config :libcluster,
  topologies: [
    mesh_k8s_topology: [
      strategy: Cluster.Strategy.DNSSRV,
      config: [
        service: "mesh-nodes",
        namespace: "production.svc.cluster.local",
        application_name: "app",
        polling_interval: 5_000
      ]
    ]
  ]
```

---

## 🔒 5. Multi-Tenant Context Isolation & Resolution

Once requests are safely passed over the mesh proxy boundary, the downstream application must extract the tenant mapping context and secure its data layer boundaries.

Tenant Resolution Logic

Router.Shared.TenantResolver isolates the leftmost string component while dropping port numbers and defending against un-isolated system endpoints:
```elixir

Returns {:ok, "tenant1"}

Router.Shared.TenantResolver.resolve("tenant1.auth.mesh.local:4000")

Returns :error (Safeguard preventing root routing access leaks)

Router.Shared.TenantResolver.resolve("auth.mesh.local")
```

Securing Stateful Phoenix LiveView Connections

Because stateful connection lifecycles bypass standard HTTP pipelines during standard WebSocket state upgrades, you must enforce a mount guard across your views. Router.Shared.Hooks.TenantLiveMount ensures that process dictionary parameters match the authenticated session:
```elixir

lib/auth_service_web/live/secure_live.ex

defmodule AuthServiceWeb.SecureLive do
use AuthServiceWeb, :live_view

Attach the isolation mount hook guard

on_mount {Router.Shared.Hooks.TenantLiveMount, :default}
def render(assigns) do
~H"""
Active Isolated Workspace for Tenant: <%= @tenant %>
"""
end
end
```

Dynamic Safeguards
Safeguarding is available by allowing you to pass a list of ignored hosts or specific keywords via application configuration. If an incoming host matches one of these safeguarded patterns, the resolver immediately returns :error instead of carving out an invalid or restricted tenant token.

How to Configure Safeguards (config/config.exs)
To activate blocklists and protect specific admin tools or edge routes from accidentally being parsed as individual tenant subdomains, add these keys to your configuration layers:

```elixir

import Config

config :router_shared,
  # 1. Block whole specific infrastructure structures using host wildcards
  ignored_host_patterns: [
    ~r/^management\..*/,                 # Blocks any domain starting with "management."
    ~r/.*\.internal\.zone$/,             # Blocks any domain ending in ".internal.zone"
    ~r/^metrics-staging-\d+\.mesh\.local/ # Blocks numeric pattern domains (e.g. metrics-staging-12.mesh.local)
  ],

  # 2. Block leftmost tenant tokens based on string rules
  restricted_tenant_patterns: [
    ~r/^(www|admin|api|root|health)$/,   # Explicit exact matches
    ~r/^internal-.*$/,                   # Blocks any leftmost tenant token starting with "internal-"
    ~r/.*-dev$/                          # Blocks any leftmost tenant token ending in "-dev"
  ]

```

Framework Configuration Mappings

Configure the multi-framework integration properties within your infrastructure configuration file (config/config.exs):

elixir config :router_shared, enable_ecto_tenant: true, ecto_repo: AuthService.Repo, enable_ash_tenant: true 

• Ecto Multi-Tenancy: Calls repo.put_tenant(tenant) dynamically on your designated repository adapter module to enforce Ecto query prefix isolation.

• Ash Framework Multi-Tenancy: Invokes Ash.set_tenant(tenant) seamlessly across the running thread stack if the framework dependency layer is available.

• Unscoped Connection Guard: If an invalid or missing tenant session is intercepted during mount initialization, the process is safely terminated via {:halt, redirect(socket, to: "/error-invalid-tenant")}.

## 🧪 6. Verification and Operational Lifecycle

Once executed, you can watch real-time lifecycle tracking notifications inside your gateway terminal logs:

When the worker successfully completes its handshake over Distributed Erlang:

[info] [Service Mesh Cluster] Dynamic node registration received from :auth_app_node@auth.mesh.local: 'auth.mesh.local' -> 10.0.0.2:4002

If that microservice machine crashes, scales down, or goes offline:

[warning] [Service Mesh Cluster] Node :auth_app_node@auth.mesh.local disconnected or crashed (Reason: :noconnection). Pruning broken routes...
[info] [Service Mesh Cluster] Deregistered route: 'auth.mesh.local' -> 10.0.0.2:4002
```
To test the path interception using curl, pass explicit host mappings or backplane override parameters targeting your gateway:
```bash

Test sub-domain parsing to access the underlying local auth service

curl -H "Host: tenant-alpha.auth.mesh.local:4000" http://localhost:4000/api/v1/session

Test direct programmatic microservice backplane routing override

curl -H "X-Backplane-Service: payment-cluster-service" http://localhost:4000/transactions/capture
```

## 🔗 7. Inter-App Communication Example (e.g., Billing to Auth)

When one internal microservice needs to communicate with another behind the gateway router (such as a **Billing** application needing to verify tokens or query data from an **Auth** application), you can route requests seamlessly using the mesh backplane routing header.

### Step 1: Register the Auth Application
Ensure your Auth application is configured with its mesh host name and includes the `ClusterLifecycleWorker` in its supervision tree:

```elixir
config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local", port: 4001],
  http: [port: 4001]
```

### Step 2: Make Requests from Billing to Auth via the Mesh Gateway
Inside your Billing application, direct HTTP or WebSocket requests to the central gateway (e.g., http://localhost:4000) and provide the x-backplane-service header specifying the target service's host key:

```elixir
defmodule Billing.AuthClient do
require Logger

def verify_user_token(token) do
gateway_url = System.get_env("GATEWAY_URL") || "http://localhost:4000"

    case Req.get("#{gateway_url}/api/v1/verify",
           headers: [
             {"x-backplane-service", "auth.mesh.local"},
             {"authorization", "Bearer #{token}"}
           ]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Billing] Auth verification failed with status #{status}: #{inspect(body)}")
        {:error, :unauthorized}

      {:error, exception} ->
        Logger.error("[Billing] Network error communicating with Auth service: #{inspect(exception)}")
        {:error, :network_error}
    end
end
end
```