    # Distributed Erlang Cluster Setup with `libcluster`

This guide explains how to automatically connect your distributed service mesh gateway and downstream application nodes using `libcluster`. This ensures that `Router.Shared.ClusterLifecycleWorker` can find the gateway node over the network automatically.

---

## 1. Prerequisites & Installation

Add `libcluster` to the dependencies inside your umbrella's root `mix.exs` or the specific configuration layer of your applications:

```elixir
def deps do
  [
    {:libcluster, "~> 3.3"}
  ]
end
```

Run `mix deps.get` to fetch the dependency.

---

## 2. Configuration Matrix

`libcluster` uses distinct topologies depending on your deployment strategy. Below are configurations for both local multi-node development and production environments.

### Option A: Local Development (`Gossip` Strategy)
The Gossip strategy utilizes UDP multicast to auto-discover other BEAM instances running on the same local network interface.

```elixir
# config/dev.exs
import Config

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

### Option B: Container / Kubernetes Deployments (`DNSSRV` Strategy)
In production cloud clusters (like AWS ECS or Kubernetes), nodes discover each other by querying a shared DNS service record.

```elixir
# config/prod.exs
import Config

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

## 3. Supervision Tree Integration

Ensure that the `Cluster.Supervisor` initializes before your lifecycle workers boot up. This ensures that the node-to-node cluster channels are established before your application attempts registration.

```elixir
# lib/gateway/application.ex or lib/auth_service/application.ex
defmodule AuthService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # 1. Start cluster discovery topologies first
      {Cluster.Supervisor, [topologies, [name: AuthService.ClusterSupervisor]]},

      # 2. Start core app mechanics
      AuthServiceWeb.Endpoint,

      # 3. Start the service mesh registration worker
      {Router.Shared.ClusterLifecycleWorker, []}
    ]

    opts = [strategy: :one_for_one, name: AuthService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## 4. Local Testing & Cluster Emulation

To emulate a cluster locally, boot two separate nodes in your terminal and pass unique short-names (`--sname`) alongside a matching magic cookie (`--cookie`).

### Step 1: Spin up the Gateway Router Node
```bash
# Start the central gateway engine
elixir --sname gateway@localhost --cookie mesh_secret_cookie -S mix phx.server
```

### Step 2: Spin up a Downstream Service Node
Open a separate terminal window and start your isolated downstream child node:
```bash
# Start the child application running on a separate port
PORT=4001 NODE_IP="localhost" elixir --sname auth@localhost --cookie mesh_secret_cookie -S mix phx.server
```

### Verification
As soon as the second node boots, `libcluster` will automatically form a connection link. You can verify network visibility directly from an interactive IEx console session or by reading your system logs:

```elixir
# Run this inside the IEx terminal session to check node visibility
Node.list()
# Returns: [:"gateway@localhost"]
```

Once visibility is achieved, your `ClusterLifecycleWorker` will output:
```text
[Mesh Network] Successfully announced route via RPC to gateway node :gateway@localhost: 'auth.mesh.local' -> localhost:4001
```
