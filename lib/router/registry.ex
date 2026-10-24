defmodule Router.Registry do
  use GenServer
  require Logger

  @moduledoc """
  Service-level registry only (NO tenant logic).
  Discovers internal Phoenix endpoint URLs at boot time across an umbrella app.
  """

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def resolve(service_host) do
    GenServer.call(__MODULE__, {:resolve, service_host})
  end

  def init(_) do
    # Boot instantly. Discover asynchronously to avoid boot-time race conditions.
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
      # 1. Check if the application specifies a primary Phoenix endpoint wrapper module
      case Application.get_env(app, :endpoint) do
        nil -> 
          []

        endpoint_module ->
          # 2. Extract configuration directly under the endpoint's configuration block
          endpoint_config = Application.get_env(app, endpoint_module, [])
          
          # 3. Pull the target service host routing key (e.g., "auth.mesh.local")
          host = Keyword.get(endpoint_config, :url, []) |> Keyword.get(:host)
          
          # 4. Resolve the real local listening port (defaults to Phoenix standard 4000)
          http_config = Keyword.get(endpoint_config, :http, [])
          port = Keyword.get(http_config, :port) || 4000

          # 5. Build a concrete connection string for ReverseProxyPlug
          if host do
            upstream_url = "localhost:#{port}"
            Logger.info("[Service Mesh Discovery] Mapping service host '#{host}' to local network path: #{upstream_url}")
            [{host, upstream_url}]
          else
            []
          end
      end
    end)
    |> Map.new()
  end
end
