# Developer Guide: Router.Shared.ClusterLifecycleWorker

The `Router.Shared.ClusterLifecycleWorker` is an automated, self-healing process designed to bridge backend microservices with the central ingress gateway. It dynamically **registers each application's network footprint and service key** with the gateway registry, supporting both local single-machine development and distributed multi-node cloud networks.

---

# How It Works (Under the Hood)

1. **Asynchronous Handshake:** When your microservice application starts up, the worker initializes asynchronously to prevent blocking the root application boot sequence.
2. **Environment Aware Reflection:** The worker reflects upon your application's Phoenix Endpoint module configuration to extract the target routing hostname key (e.g., `auth.mesh.local`), the designated local port, and the current container or instance network address.
3. **Dynamic Topology Scaling:**
   * **Local Non-Distributed Mode:** If the gateway runs on the same node, it hooks directly into local memory parameters to synchronize the routing map.
   * **Distributed Multi-Node Mode:** If the gateway runs on a separate machine, it initiates an Erlang RPC call (`:rpc.call/4`) straight into the central gateway registry process across the cluster network.
4. **Stateful Process Heartbeat:** During remote registration, the gateway router creates a bidirectional process link (`Process.link/1`) directly to the lifecycle worker. If the microservice container crashes, scales down, or gets isolated by a network partition, the gateway instantly traps the exit signal, prunes the dead route, and keeps its routing state clean.
5. **Self-Healing Loop:** If the gateway node goes offline or boots slower than your microservice application, the worker schedules a non-blocking retry timer to re-evaluate the connection every 5 seconds until a handshake is established.

---

# How to Use It (Step-by-Step Implementation)

### Step 1: Add it to your Child App's Supervision Tree
Open the application definition file of your microservice (e.g., `apps/auth_app/lib/auth_app/application.ex`). Drop the lifecycle worker into the children list **immediately after** your web endpoint process has initialized:

```elixir
defmodule AuthApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AuthApp.Repo,
      AuthAppWeb.Telemetry,
      {Phoenix.PubSub, name: AuthApp.PubSub},
      AuthAppWeb.Endpoint, # <--- 1. Web endpoint initializes first
      
      # 2. Add the worker loop here to announce the endpoint to the gateway
      {Router.Shared.ClusterLifecycleWorker, []}
    ]

    opts = [strategy: :one_for_one, name: AuthApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Step 2: Configure Environment Profiles
Configure your environments (e.g., `apps/auth_app/config/config.exs`) to inform the worker which application context to inspect and where the gateway node lives on the network matrix.

#### Profile A: Configuration for Local Development (Single Machine / Umbrella)
If you are running the entire system cluster locally using a single `mix phx.server` deployment, leave the `gateway_node` configuration parameter unset or default it to your current node. It will safely map all endpoints directly to `localhost`:

```elixir
import Config

config :auth_app, :endpoint, AuthAppWeb.Endpoint

config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"], 
  http: [port: 4002]

# Shared configuration block settings
config :router_shared,
  app_name: :auth_app # Tells the worker to read settings from the :auth_app block
```

#### Profile B: Configuration for Distributed Production (Multi-Node Clusters)
When deploying separate apps to different cloud instances, virtual machines, or separate Docker containers, configure the system to look up your host node identifiers dynamically:

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

> **Production Deployment Tip:** Inside production containers or multi-node VMs, ensure you pass the host container's private cloud network IP into the `NODE_IP` environment variable (e.g., `NODE_IP=10.0.0.2`), which the worker automatically queries at runtime to build a clean connection string.

---

# Verification and Operational Lifecycle

Once configured and executed, you can watch real-time lifecycle tracking notifications inside your gateway terminal logs:

```text
# When the worker successfully completes its handshake over Distributed Erlang:
[info] [Service Mesh Cluster] Dynamic node registration received from :auth_app_node@auth.mesh.local: 'auth.mesh.local' -> 10.0.0.2:4002

# If that microservice machine crashes, scales down, or goes offline:
[warn] [Service Mesh Cluster] Remote endpoint connection dropped: :noconnection. Pruning mappings...
[info] [Service Mesh Cluster] Deregistered route: 'auth.mesh.local' -> 10.0.0.2:4002
```
