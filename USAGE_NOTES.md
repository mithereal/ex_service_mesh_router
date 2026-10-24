Setup Guide: ExServiceMeshRouter in Phoenix Umbrellas
This guide walks you through installing and configuring ExServiceMeshRouter as a BEAM-native edge gateway and internal backplane within an Elixir Umbrella project running Bandit.
---
1. Directory Structure
Ensure your umbrella project follows this architecture. The gateway router (`router`) and shared multi-tenancy code (`router_shared`) should live as isolated applications alongside your business microservices.
```text
my_umbrella/
├── apps/
│   ├── router/                 # The Edge Mesh Gateway Application
│   ├── router_shared/          # Shared Tenant Pipeline, Resolver, and Configs
│   ├── auth_app/               # Downstream Phoenix Application (e.g., Authentication)
│   └── chat_app/               # Downstream Phoenix Application (e.g., Live Chat Engine)
```
---
2. Shared Core Installation (`apps/router_shared`)
The `router_shared` package isolates multi-tenant parsing logic so that backend apps can consume it uniformly, keeping the top-level edge router completely agnostic of tenant logic.
Dependency Configuration (`apps/router_shared/mix.exs`)
```elixir
defp deps do
  [
    {:plug, "~> 1.16"},
    {:jason, "~> 1.4"},
    {:ecto_sql, "~> 3.11", optional: true},
    {:ash, "~> 3.0", optional: true}
  ]
end
```
The Tenant Resolver Module (`apps/router_shared/lib/tenant_resolver.ex`)
```elixir
defmodule Router.Shared.TenantResolver do
  @moduledoc """
  Extracts the tenant identifier from the incoming request host string.
  Expects format: tenant.service.tld (e.g., "acme.auth.mesh.local")
  """

  @spec resolve(String.t() | nil) :: {:ok, String.t()} | :error
  def resolve(nil), do: :error
  def resolve(host) do
    clean_host = host |> String.split(":") |> List.first()

    case String.split(clean_host, ".") do
      [tenant, _service, _tld] -> {:ok, tenant}
      _ -> :error
    end
  end
end
```
The Tenant Pipeline Plug (`apps/router_shared/lib/plugs/tenant_pipeline.ex`)
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
        |> assign(:tenant, tenant)
        |> maybe_put_ecto_tenant(tenant)
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
    if Application.get_env(:router_shared, :enable_ecto_tenant, false) do
      repo = Application.get_env(:router_shared, :ecto_repo)
      if repo, do: repo.put_tenant(tenant)
    end
    conn
  end

  defp maybe_put_ash_tenant(conn, tenant) do
    if Application.get_env(:router_shared, :enable_ash_tenant, false) and Code.ensure_loaded?(Ash) do
      Ash.set_tenant(tenant)
    end
    conn
  end
end
```
---
3. Gateway Installation (`apps/router`)
The `router` application acts strictly as a lightweight, dual-protocol reverse proxy that handles service routing without processing tenancy boundaries.
Dependency Configuration (`apps/router/mix.exs`)
```elixir
defp deps do
  [
    {:bandit, "~> 1.5"},
    {:reverse_proxy_plug, "~> 3.0"},
    {:reverse_proxy_plug_websocket, "~> 0.2.0"},
    {:gun, "~> 2.1"}
  ]
end
```
The Service Discovery Registry (`apps/router/lib/router/registry.ex`)
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
The Edge Router (`apps/router/lib/router/router.ex`)
```elixir
defmodule Router.Router do
  import Plug.Conn
  alias Router.Registry

  def init(opts), do: opts

  def call(conn, _opts) do
    host = conn |> get_req_header("host") |> List.first() |> normalize_host()
    service_host = extract_service_host(host)

    case Registry.resolve(service_host) do
      nil -> send_resp(conn, 404, "Unknown service: #{service_host}")
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
The Supervisor (`apps/router/lib/router/application.ex`)
```elixir
defmodule Router.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      Router.Registry,
      {Bandit, plug: Router.Router, port: String.to_integer(System.get_env("GATEWAY_PORT") || "4000")}
    ]

    opts = [strategy: :one_for_one, name: Router.Supervisor]
    Logger.info("[ExServiceMeshRouter] Gateway running on port 4000...")
    Supervisor.start_link(children, opts)
  end
end
```
---
4. Downstream Application Setup (e.g., `apps/auth_app`)
Configure downstream apps to announce themselves to the router and parse tenants securely using the shared pipeline.
Dependency Configuration (`apps/auth_app/mix.exs`)
Include the shared configuration library inside your microservices:
```elixir
defp deps do
  [
    {:router_shared, in_umbrella: true}
  ]
end
```
Application Environment Profiles (`apps/auth_app/config/config.exs`)
```elixir
import Config

# 1. Announce the Phoenix Endpoint module to the Mesh Discovery engine
config :auth_app, :endpoint, AuthAppWeb.Endpoint

# 2. Configure the local listening port and matching service host router key
config :auth_app, AuthAppWeb.Endpoint,
  url: [host: "auth.mesh.local"], 
  http: [port: 4002]

# 3. Enable Ecto / Ash multi-tenancy configurations if required
config :router_shared,
  enable_ecto_tenant: true,
  ecto_repo: AuthApp.Repo,
  enable_ash_tenant: false
```
Activating the Boundary Guard (`apps/auth_app/lib/auth_app_web/router.ex`)
```elixir
defmodule AuthAppWeb.Router do
  use AuthAppWeb, :router

  pipeline :tenant_isolated do
    plug Router.Shared.Plugs.TenantPipeline
  end

  scope "/", AuthAppWeb do
    pipe_through [:browser, :tenant_isolated]

    get "/", PageController, :home
    # Sockets, HTTP routes, and LiveViews run securely isolated under the tenant scope
  end
end
```