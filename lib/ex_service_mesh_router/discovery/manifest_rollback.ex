defmodule ExServiceMeshRouter.Discovery.ManifestRollback do
  @moduledoc """
  Handles rollback of Phoenix app routing manifests to a previous version.

  Responsibilities:
  - Retrieve historical manifest version
  - Compare against current manifest
  - Compute diff
  - Apply reverse patch via ManifestPatcher
  - Update ManifestStore to rolled-back version

  This enables time-travel for routing state.
  """

  alias ExServiceMeshRouter.Discovery.{
    ManifestStore,
    ManifestVersions,
    ManifestDiff,
    ManifestPatcher
    }

  @doc """
  Roll back a given app to a specific manifest version.
  """
  def rollback(app, target_version) when is_integer(target_version) do
    with {:ok, current} <- current_manifest(app),
         {:ok, target} <- ManifestVersions.get(app, target_version) do

      diff =
        ManifestDiff.diff(current.manifest, target)

      ManifestPatcher.apply(app, diff)

      ManifestStore.put(app, target, target_version)

      {:ok, %{app: app, rolled_back_to: target_version}}
    else
      :error ->
        {:error, :manifest_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Roll back to the previous known version.
  """
  def rollback_previous(app) do
    case ManifestVersions.latest(app) do
      nil ->
        {:error, :no_versions_available}

      {latest_version, _manifest} when latest_version <= 1 ->
        {:error, :cannot_rollback_further}

      {latest_version, _manifest} ->
        rollback(app, latest_version - 1)
    end
  end

  @doc """
  Roll forward (re-apply a newer version after rollback).
  Useful for testing routing drift correction.
  """
  def rollback_forward(app) do
    case ManifestVersions.latest(app) do
      nil ->
        {:error, :no_versions_available}

      {latest_version, _} ->
        rollback(app, latest_version)
    end
  end

  defp current_manifest(app) do
    case ManifestStore.get(app) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :no_current_manifest}
    end
  end
end