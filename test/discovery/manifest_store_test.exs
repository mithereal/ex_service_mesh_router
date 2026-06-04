defmodule ExServiceMeshRouter.ManifestStoreTest do
  use ExUnit.Case, async: true

  alias ExServiceMeshRouter.Discovery.ManifestStore
  import ExServiceMeshRouter.TestHelpers

  test "stores and retrieves manifest with versioning" do
    ManifestStore.update(:app_a, sample_manifest())

    assert {:ok, %{manifest: m, version: v}} = ManifestStore.get(:app_a)
    assert v == 1
    assert Map.has_key?(m, :http)
  end

  test "increments versions on update" do
    ManifestStore.update(:app_a, sample_manifest())
    ManifestStore.update(:app_a, sample_manifest())

    assert {:ok, %{version: 2}} = ManifestStore.get(:app_a)
  end
end