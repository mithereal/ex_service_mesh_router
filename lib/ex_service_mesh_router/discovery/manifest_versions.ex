defmodule ExServiceMeshRouter.Discovery.ManifestVersions do
  @moduledoc """
  Stores historical versions of routing manifests per app.

  Responsibilities:
  - Persist immutable manifest snapshots
  - Provide version lookup for rollback
  - Track latest version per app
  - Feed ManifestRollback + ManifestDiff
  """

  @table :mesh_manifest_versions

  use GenServer

  # -------------------------
  # STARTUP
  # -------------------------

  def start_link(_),
      do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    :ets.new(@table, [
      :bag,
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
  Store a new manifest version for an app.
  """
  def put(app, manifest, version) when is_integer(version) do
    :ets.insert(@table, {app, version, normalize(manifest)})
    :ok
  end

  @doc """
  Retrieve a specific version.
  """
  def get(app, version) do
    case :ets.match_object(@table, {app, version, :_}) do
      [{^app, ^version, manifest}] ->
        {:ok, %{version: version, manifest: manifest}}

      [] ->
        :error
    end
  end

  @doc """
  Get latest version for an app.
  """
  def latest(app) do
    @table
    |> :ets.match_object({app, :"$1", :"$2"})
    |> Enum.map(fn {_, v, m} -> {v, m} end)
    |> Enum.sort_by(fn {v, _} -> v end, :desc)
    |> case do
         [] -> nil
         [{v, m} | _] -> {v, m}
       end
  end

  @doc """
  List all versions for an app.
  """
  def list(app) do
    @table
    |> :ets.match_object({app, :"$1", :"$2"})
    |> Enum.map(fn {_, v, m} -> {v, m} end)
    |> Enum.sort_by(fn {v, _} -> v end)
  end

  # -------------------------
  # INTERNAL
  # -------------------------

  defp normalize(%{} = manifest), do: manifest
  defp normalize(_), do: %{}
end