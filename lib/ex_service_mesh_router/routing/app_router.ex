defmodule ExServiceMeshRouter.Router.AppRouter do
  @moduledoc """
  Service discovery layer for Phoenix apps participating in the mesh.

  Responsibilities:
  - Maintain registry of known Phoenix apps
  - Resolve app → endpoint mapping
  - Provide discovery fallback for unknown apps
  - Support ManifestSync and routing pipeline
  """

  use GenServer

  @table :mesh_registry

  # -------------------------
  # STARTUP
  # -------------------------

  def start_link(_),
      do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])

    {:ok, %{}}
  end

  # -------------------------
  # PUBLIC API
  # -------------------------

  @doc """
  Resolve an app to its endpoint.
  """
  def lookup(app) do
    case :ets.lookup(@table, app) do
      [{^app, endpoint}] ->
        {:ok, endpoint}

      [] ->
        discover(app)
    end
  end

  @doc """
  List all known apps in the mesh.
  """
  def list_apps do
    :ets.tab2list(@table)
    |> Enum.map(fn {app, _endpoint} -> app end)
  end

  @doc """
  Manually register an app endpoint.
  Useful for bootstrapping or external discovery systems.
  """
  def register(app, endpoint) when is_map(endpoint) do
    :ets.insert(@table, {app, normalize(endpoint)})
    {:ok, app}
  end

  @doc """
  Remove an app from the registry.
  """
  def unregister(app) do
    :ets.delete(@table, app)
    :ok
  end

  # -------------------------
  # DISCOVERY LOGIC
  # -------------------------

  defp discover(app) do
    endpoint = default_endpoint(app)

    :ets.insert(@table, {app, endpoint})

    {:ok, endpoint}
  end

  defp default_endpoint(app) do
    %{
      host: "localhost",
      port: base_port(app),
      ws_path: "/socket/websocket"
    }
  end

  defp base_port(app) do
    4000 + :erlang.phash2(app, 100)
  end

  # -------------------------
  # NORMALIZATION
  # -------------------------

  defp normalize(endpoint) do
    %{
      host: Map.get(endpoint, :host, "localhost"),
      port: Map.get(endpoint, :port, 4000),
      ws_path: Map.get(endpoint, :ws_path, "/socket/websocket")
    }
  end
end