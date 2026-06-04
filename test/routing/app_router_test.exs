defmodule ExServiceMeshRouter.AppRouterTest do
  use ExUnit.Case
  use Plug.Test

  alias ExServiceMeshRouter.Routing.AppRouter
  alias ExServiceMeshRouter.Discovery.{ManifestStore, AutoRegistry}

  import ExServiceMeshRouter.TestHelpers

  setup do
    AutoRegistry.register(:app_a, %{host: "localhost", port: 4001})
    ManifestStore.update(:app_a, sample_manifest())
    :ok
  end

  test "routes valid request" do
    conn =
      conn(:get, "/apps/app_a/api/users")
      |> AppRouter.route()

    assert conn.status == 202
  end

  test "rejects invalid route" do
    conn =
      conn(:get, "/apps/app_a/invalid")
      |> AppRouter.route()

    assert conn.status == 404
  end
end