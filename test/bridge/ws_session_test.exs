defmodule ExServiceMeshRouter.Discovery.ManifestRollbackTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Discovery.{
    ManifestStore,
    ManifestVersions,
    ManifestRollback
    }

  @manifest_v1 %{
    http: %{
      "/api/users" => ["GET"]
    },
    ws: %{
      topics: ["room:*"]
    },
    domains: ["localhost"]
  }

  @manifest_v2 %{
    http: %{
      "/api/users" => ["GET", "POST"]
    },
    ws: %{
      topics: ["room:*", "user:*"]
    },
    domains: ["localhost"]
  }

  @manifest_v3 %{
    http: %{
      "/api/users" => ["GET", "POST", "DELETE"]
    },
    ws: %{
      topics: ["room:*", "user:*", "admin:*"]
    },
    domains: ["localhost"]
  }

  # ============================================================
  # SETUP: build version history
  # ============================================================

  setup do
    ManifestVersions.put(:app_a, @manifest_v1, 1)
    ManifestStore.put(:app_a, @manifest_v1, 1)

    ManifestVersions.put(:app_a, @manifest_v2, 2)
    ManifestStore.put(:app_a, @manifest_v2, 2)

    ManifestVersions.put(:app_a, @manifest_v3, 3)
    ManifestStore.put(:app_a, @manifest_v3, 3)

    :ok
  end

  # ============================================================
  # ROLLBACK TO PREVIOUS VERSION
  # ============================================================

  test "rolls back to previous manifest version" do
    assert {:ok, result} =
             ManifestRollback.rollback(:app_a, 2)

    assert result.rolled_back_to == 2

    {:ok, %{version: v}} = ManifestStore.get(:app_a)
    assert v == 2
  end

  # ============================================================
  # ROLLBACK FURTHER BACK
  # ============================================================

  test "rolls back to version 1 successfully" do
    assert {:ok, _} =
             ManifestRollback.rollback(:app_a, 1)

    {:ok, %{version: v}} = ManifestStore.get(:app_a)
    assert v == 1
  end

  # ============================================================
  # ROLLBACK PREVIOUS (AUTO STEP BACK)
  # ============================================================

  test "rollback_previous steps back one version" do
    # current assumed v3 from setup
    assert {:ok, _} =
             ManifestRollback.rollback_previous(:app_a)

    {:ok, %{version: v}} = ManifestStore.get(:app_a)

    assert v == 2
  end

  # ============================================================
  # ROLLBACK FORWARD (REAPPLY LATEST)
  # ============================================================

  test "rollback_forward restores latest version" do
    # step back first
    ManifestRollback.rollback(:app_a, 1)

    # then forward
    assert {:ok, _} =
             ManifestRollback.rollback_forward(:app_a)

    {:ok, %{version: v}} = ManifestStore.get(:app_a)
    assert v == 3
  end

  # ============================================================
  # INVALID ROLLBACK CASES
  # ============================================================

  test "returns error when version does not exist" do
    assert {:error, _} =
             ManifestRollback.rollback(:app_a, 999)
  end

  # ============================================================
  # NO HISTORY EDGE CASE
  # ============================================================

  test "rollback fails gracefully with no versions" do
    assert {:error, _} =
             ManifestRollback.rollback(:unknown_app, 1)
  end
end