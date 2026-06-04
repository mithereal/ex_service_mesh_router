defmodule ExServiceMeshRouter.Discovery.ManifestStore do
  @moduledoc """
  Runtime store for Phoenix app routing manifests.

  Responsibilities:
  - Store latest manifest per app
  - Track versioned manifest state
  - Provide fast lookup for routing pipeline
  - Serve as source of truth for validation and routing decisions
  """

  use GenServer

  @table :mesh_manifests

  # -------------------------
  # PUBLIC API
  # -------------------------

  def start_link(_),
      do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @doc """
  Fetch the latest manifest for an app.
  """
  def get(app) do
    case :ets.lookup(@table, app) do
      [{^app, data}] -> {:ok, data}
      [] -> :error
    end
  end

  @doc """
  Store a new manifest version for an app.
  """
  def put(app, manifest, version) when is_integer(version) do
    :ets.insert(@table, {app, build_entry(manifest, version)})
  end

  @doc """
  Update manifest with auto-incremented version.
  """
  def update(app, manifest) do
    version = next_version(app)
    put(app, manifest, version)
    {:ok, version}
  end

  @doc """
  Get just the raw manifest (no metadata wrapper).
  """
  def get_manifest(app) do
    case get(app) do
      {:ok, %{manifest: manifest}} -> {:ok, manifest}
      _ -> :error
    end
  end

  @doc """
  Get current version number for an app.
  """
  def get_version(app) do
    case get(app) do
      {:ok, %{version: v}} -> {:ok, v}
      _ -> :error
    end
  end

  # -------------------------
  # INTERNAL HELPERS
  # -------------------------

  defp build_entry(manifest, version) do
    %{
      manifest: normalize_manifest(manifest),
      version: version,
      updated_at: System.system_time(:second)
    }
  end

  defp normalize_manifest(%{} = manifest), do: manifest
  defp normalize_manifest(_), do: %{}

  defp next_version(app) do
    case get(app) do
      {:ok, %{version: v}} -> v + 1
      _ -> 1
    end
  end
end