# Umbrella Application Integration Guide

This guide details how to seamlessly embed the BEAM-native service mesh gateway architecture into your existing Elixir umbrella application workspace. By introducing these layers, you enable zero-config service discovery, dynamic routing across child apps, and centralized multi-framework tenant state tracking.

---

## 🗂️ 1. Root Dependencies

Add the core routing engine and proxy dependencies directly to your umbrella's root `mix.exs` file:

```elixir
defp deps do
  [
    {:ex_service_mesh_router, github: "mitherealpub/ex_service_mesh_router"},
    {:reverse_proxy_plug, "~> 3.0"},
    {:reverse_proxy_plug_websocket, "~> 0.3.0"},
    {:bandit, "~> 1.5"}
  ]
end
```

Run `mix deps.get` in your root workspace terminal directory to fetch and sync the new layers.

---

## 🌐 2. Initializing the Gateway Sub-App

If you do not have an edge proxy or web sub-app layer inside your `apps/` directory, spin up a lean OTP child app dedicated to ingress forwarding:

```bash
cd apps
mix new gateway --sup
```

Navigate to `apps/gateway/lib/gateway/application.ex` and mount the service registry alongside the high-performance Bandit interceptor server:

```elixir
defmodule Gateway.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Router.Registry, name: Router.Registry},
      {Bandit, plug: Router.Router, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: Gateway.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## 🚀 3. Connecting Downstream Sub-Apps

To link child web endpoints to your gateway, place the `ClusterLifecycleWorker` process into your respective microservices' supervision trees (e.g., `apps/auth_app/lib/auth_app/application.ex`):

```elixir
defmodule AuthApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AuthApp.Repo,
      AuthAppWeb.Endpoint,
      
      # Announces this endpoint's runtime path mapping to the gateway
      {Router.Shared.ClusterLifecycleWorker, []}
    ]

    opts = [strategy: :one_for_one, name: AuthApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## ⚙️ 4. Shared Topology & Tenant Config

Define your port parameters and tenant routing constraints inside your global umbrella `config/config.exs` or `config/runtime.exs` script maps:

```elixir
import Config

# Ingress Engine Base Parameters
config :ex_service_mesh_router, Router.Router,
  http_port: String.to_integer(System.get_env("GATEWAY_PORT") || "4000")

# Child App Settings (Ensure ports are unique to prevent local boot collisions)
config :auth_app, :endpoint, AuthAppWeb.Endpoint
config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"], 
  http: [port: 4002]

# Context Management Rules
config :router_shared,
  app_name: :auth_app,
  gateway_node: Node.self(), # Use specific named atoms in distributed clusters
  enable_ecto_tenant: true,
  ecto_repo: AuthApp.Repo,
  enable_ash_tenant: false
```

---

## 🔒 5. Securing Stateful Connection Lifecycles

Because stateful WebSockets (Phoenix Channels, LiveView streams) bypass typical linear HTTP pipelines during connection upgrades, attach the lifecycle isolation mount hook inside your endpoint routers:

```elixir
defmodule AuthAppWeb.Router do
  use AuthAppWeb, :router

  # Re-applies process-dictionary side effects across stateful LiveView loops
  live_session :secure_mesh, on_mount: [{Router.Shared.Hooks.TenantLiveMount, :default}] do
    live "/dashboard", DashboardLive
  end
end
```
*Any unscoped session connection will be instantly intercepted and redirected to `/error-invalid-tenant`.*

---

## 📦 6. Compiling Isolated Releases

To containerize your child apps into lean, production-ready microservice artifacts, map out explicit release binaries inside your **root `mix.exs`** block:

```elixir
def project do
  [
    apps_path: "apps",
    version: "1.0.0",
    elixir: "~> 1.15",
    deps: deps(),
    releases: [
      gateway: [
        include_executables_for: [:unix],
        applications: [gateway: :permanent]
      ],
      auth_app: [
        include_executables_for: [:unix],
        applications: [auth_app: :permanent]
      ]
    ]
  ]
end
```
