defmodule ExServiceMeshRouter.Discovery.AutoRegistry do
  @moduledoc """
  Auto-discovery registry for Phoenix apps in the service mesh.

  Responsibilities:
  - Discover apps from apps/*/priv/manifest.json
  - Load and cache endpoint + manifest metadata
  - Provide fast lookup for routing + WS bridging
  - Support runtime reload / refresh
  """

  use GenServer

  @table :mesh_auto_registry
  @manifest_glob "apps/*/priv/manifest.json"

  # ============================================================
  # PUBLIC API
  # ============================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true
    ])

    {:ok, %{}, {:continue, :bootstrap}}
  end

  # ------------------------------------------------------------
  # BOOTSTRAP / RELOAD
  # ------------------------------------------------------------

  def handle_continue(:bootstrap, state) do
    load_all()
    {:noreply, state}
  end

  @doc """
  Forces full rediscovery of all apps.
  """
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  def handle_call(:reload, _from, state) do
    :ets.delete_all_objects(@table)
    load_all()
    {:reply, :ok, state}
  end

  # ------------------------------------------------------------
  # LOOKUP
  # ------------------------------------------------------------

  @doc """
  Lookup app endpoint + manifest.
  """
  def lookup(app) do
    case :ets.lookup(@table, app) do
      [{^app, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns all registered apps.
  """
  def list do
    :ets.tab2list(@table)
    |> Enum.map(fn {app, _} -> app end)
  end

  @doc """
  Returns full registry dump.
  """
  def dump do
    :ets.tab2list(@table)
  end

  # ============================================================
  # DISCOVERY CORE
  # ============================================================

  defp load_all do
    @manifest_glob
    |> Path.wildcard()
    |> Enum.each(&load_manifest/1)
  end

  defp load_manifest(path) do
    case File.read(path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, manifest} ->
            register_manifest(manifest)

          {:error, _} ->
            :ignore
        end

      {:error, _} ->
        :ignore
    end
  end

  # ------------------------------------------------------------
  # REGISTRATION LOGIC
  # ------------------------------------------------------------

  def register(app, endpoint) when is_atom(app) do
    :ets.insert(@table, {app, normalize_endpoint(endpoint)})
    :ok
  end

  def register_manifest(%{"app" => app} = manifest) do
    app_atom = String.to_atom(app)

    endpoint = %{
      app: app_atom,
      host: Map.get(manifest, "host", "localhost"),
      port: Map.get(manifest, "port", default_port(app_atom)),
      ws_path: Map.get(manifest, "ws_path", "/socket/websocket"),
      manifest: normalize_manifest(manifest)
    }

    :ets.insert(@table, {app_atom, endpoint})
    :ok
  end

  # ============================================================
  # NORMALIZATION
  # ============================================================

  defp normalize_endpoint(endpoint) do
    Map.merge(%{ws_path: "/socket/websocket"}, endpoint)
  end

  defp normalize_manifest(manifest) when is_map(manifest) do
    %{
      http: Map.get(manifest, "http", %{}),
      ws: Map.get(manifest, "ws", %{"topics" => []}),
      domains: Map.get(manifest, "domains", ["localhost"]),
      version: Map.get(manifest, "version", 1)
    }
  end

  defp default_port(app) do
    # deterministic porting for local dev mesh
    base = :erlang.phash2(app, 1000)
    4000 + base
  end
end