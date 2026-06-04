defmodule ExServiceMeshRouter.Mesh.Diff do
  @moduledoc """
  Computes manifest diffs for incremental compilation.
  """

  def changed?(old_manifest, new_manifest) do
    old_manifest != new_manifest
  end

  def diff(old_manifest, new_manifest) do
    %{
      changed: changed?(old_manifest, new_manifest),
      old: old_manifest,
      new: new_manifest
    }
  end
end