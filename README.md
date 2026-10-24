# ExServiceMeshRouter

A BEAM-native service mesh gateway for Phoenix umbrella applications with automatic service discovery. Tenant handling is owned by each Phoenix application.

---

# Architecture Overview

## Request Flow
```text
Client Request  
→ Gateway Router (Dual HTTP & WebSocket Interceptor via Router.Router)
→ Service Registry (Extracts host → Resolves proxy network upstream string via Router.Registry)  
→ Bandit Web Server Proxying (via ReverseProxyPlug / ReverseProxyPlugWebsocket)
→ Target Phoenix Application Endpoint (e.g., localhost:4002)
→ Phoenix App Router  
→ Shared Tenant Plug (Inside the child application runtime context)  
→ Controllers / LiveView / Ash / Ecto Isolated Database Boundary
```

---

# Project Structure

```text
my_umbrella/
├── apps/
│   ├── ex_service_mesh_router/   # Gateway Application (Service-Only Proxy)
│   │   ├── lib/
│   │   │   ├── application.ex    # Starts Router.Registry and Bandit Server
│   │   │   ├── router.ex         # Intercepts HTTP vs WebSockets upgrades
│   │   │   └── registry.ex       # Dynamic Async Service discovery
│   │   └── mix.exs
│   │
│   ├── router_shared/            # Shared Library (Dependency for child apps only)
│   │   ├── lib/
│   │   │   ├── tenant_resolver.ex
│   │   │   ├── hooks/
│   │   │   │   └── tenant_live_mount.ex # LiveView state synchronization
│   │   │   └── plugs/
│   │   │       └── tenant_pipeline.ex # Safe Ecto & Ash runtime scopes
│   │   └── mix.exs
```

---

# 1. Shared Core Application Layout (`apps/router_shared`)

### Dependency Configuration (`apps/router_shared/mix.exs`)
```elixir
defmodule Router.Shared.MixProject do
  use Mix.Project

  def project do
    [
      app: :router_shared,
      version: "1.0.0",
      in_umbrella: true,
      elixir: "~> 1.15",
      deps: deps()
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11", optional: true},
      {:ash, "~> 3.0", optional: true}
    ]
  end
end
```

### The Tenant Resolver Module (`apps/router_shared/lib/tenant_resolver.ex`)
```elixir
defmodule Router.Shared.TenantResolver do
  @moduledoc """
  Extracts the tenant identifier from the incoming request host string.
  Expects format: tenant.service.tld (e.g., "acme.auth.mesh.local")
  """

  @spec resolve(String.t() | nil) :: {:ok, String.t()} | :error
  def resolve(nil), do: :error
  def resolve(host) do
    # Remove any trailing port number if present (e.g., "acme.auth.mesh.local:4000")
    clean_host = host |> String.split(":") |> List.first()

    case String.split(clean_host, ".") do
      [tenant, _service, _tld] -> {:ok, tenant}
      _ -> :error
    end
  end
end
```

### The Tenant Pipeline Plug (`apps/router_shared/lib/plugs/tenant_pipeline.ex`)
```elixir
defmodule Router.Shared.Plugs.TenantPipeline do
  import Plug.Conn
  alias Router.Shared.TenantResolver
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    host = conn |> get_req_header("host") |> List.first()

    case TenantResolver.resolve(host) do
      {:ok, tenant} ->
        conn
        # 1. Always assign tenant identifier to connection metadata
        |> assign(:tenant, tenant)
        # 2. Put into cookie/plug session so state transfers downstream to LiveView
        |> put_session("tenant", tenant)
        # 3. Conditionally apply Ecto routing side effects safely
        |> maybe_put_ecto_tenant(tenant)
        # 4. Conditionally apply Ash framework process context scopes safely
        |> maybe_put_ash_tenant(tenant)

      :error ->
        Logger.warning("[Tenant Isolation Engine] Rejected unresolvable host: #{inspect(host)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Bad Request", message: "Missing or invalid tenant scope"}))
        |> halt() 
    end
  end

  defp maybe_put_ecto_tenant(conn, tenant) do
    case Application.get_env(:router_shared, :enable_ecto_tenant, false) do
      true ->
        repo = Application.get_env(:router_shared, :ecto_repo)
        if repo do
          _ = repo.put_tenant(tenant)
          conn
        else
          Logger.error("[Tenant Isolation Engine] Config error: :enable_ecto_tenant is true but :ecto_repo is missing.")
          conn
        end
      false ->
        conn
    end
  end

  defp maybe_put_ash_tenant(conn, tenant) do
    case Application.get_env(:router_shared, :enable_ash_tenant, false) do
      true ->
        if Code.ensure_loaded?(Ash) do
          _ = Ash.set_tenant(tenant)
          conn
        else
          Logger.error("[Tenant Isolation Engine] Config error: :enable_ash_tenant is true but Ash package is not loaded.")
          conn
        end
      false ->
        conn
    end
  end
end
```

---

# 2. Gateway Application Layout (`apps/ex_service_mesh_router`)

### Dependency Configuration (`apps/ex_service_mesh_router/mix.exs`)
```elixir
defmodule ExServiceMeshRouter.MixProject do
  use Mix.Project

  @version "1.0.1"
  @source_url "https://github.com"

  def project do
    [
      app: :ex_service_mesh_router,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ExServiceMeshRouter",
      package: package(),
      description: "A BEAM-native service mesh gateway for Phoenix umbrella applications.",
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test]
    ]
  end

  def application do
    [
      mod: {ExServiceMeshRouter.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp package do
    [
      name: "ex_service_mesh_router",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Jason Clark"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps do
    [
      {:reverse_proxy_plug, "~> 3.0"},
      {:reverse_proxy_plug_websocket, "~> 0.2.0"},
      {:gun, "~> 2.1"},
      {:req, "~> 0.5"},
      {:bandit, "~> 1.5"},
      {:plug_cowboy, "~> 2.7", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:excoveralls, "~> 0.14", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
```

### The Service Discovery Registry (`apps/ex_service_mesh_router/lib/router/registry.ex`)
```elixir
defmodule Router.Registry do
  use GenServer
  require Logger

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def resolve(service_host), do: GenServer.call(__MODULE__, {:resolve, service_host})

  def init(_) do
    send(self(), :discover_services)
    {:ok, %{}}
  end

  def handle_call({:resolve, service_host}, _from, state) do
    {:reply, Map.get(state, service_host), state}
  end

  def handle_info(:discover_services, _state) do
    {:noreply, fetch_service_mappings()}
  end

  defp fetch_service_mappings do
    Application.loaded_applications()
    |> Enum.flat_map(fn {app, _, _} ->
      case Application.get_env(app, :endpoint) do
        nil -> []
        endpoint_module ->
          if Code.ensure_loaded?(endpoint_module) do
            http_config = endpoint_module.config(:http) || []
            port = Keyword.get(http_config, :port) || 4000
            
            url_config = endpoint_module.config(:url) || []
            host = Keyword.get(url_config, :host)

            if host, do: [{"#{host}", "localhost:#{port}"}], else: []
          else
            []
          end
      end
    end)
    |> Map.new()
  end
end
```

### The Edge Router Proxy (`apps/ex_service_mesh_router/lib/router/router.ex`)
```elixir
defmodule Router.Router do
  import Plug.Conn
  alias Router.Registry

  def init(opts), do: opts

  def call(conn, _opts) do
    host = conn |> get_req_header("host") |> List.first() |> normalize_host()
    service_host = extract_service_host(host)

    case Registry.resolve(service_host) do
      nil -> send_resp(conn, 404, "Unknown service over mesh: #{service_host}")
      endpoint ->
        if websocket_upgrade?(conn) do
          forward_websocket(conn, endpoint)
        else
          forward_http(conn, endpoint)
        end
    end
  end

  defp extract_service_host(nil), do: ""
  defp extract_service_host(host) do
    case String.split(host, ".") do
      [_tenant, service, tld] -> "#{service}.#{tld}"
      _ -> host
    end
  end

  defp websocket_upgrade?(conn) do
    case get_req_header(conn, "upgrade") |> List.first() do
      nil -> false
      header -> String.downcase(header) == "websocket"
    end
  end

  defp forward_http(conn, endpoint) do
    ReverseProxyPlug.call(conn, upstream: "http://" <> endpoint)
  end

  defp forward_websocket(conn, endpoint) do
    opts = ReverseProxyPlugWebsocket.init(upstream_uri: "ws://" <> endpoint)
    ReverseProxyPlugWebsocket.call(conn, opts)
  end

  defp normalize_host(nil), do: nil
  defp normalize_host(host), do: host |> String.split(":") |> List.first()
end
```

### The Supervisor (`apps/ex_service_mesh_router/lib/router/application.ex`)
```elixir
defmodule ExServiceMeshRouter.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("GATEWAY_PORT") || "4000")

    children = [
      Router.Registry,
      {Bandit, plug: Router.Router, port: port}
    ]

    opts = [strategy: :one_for_one, name: ExServiceMeshRouter.Supervisor]
    Logger.info("[ExServiceMeshRouter] Starting pure-Elixir Bandit edge gateway on port #{port}...")
    Supervisor.start_link(children, opts)
end
end
```
