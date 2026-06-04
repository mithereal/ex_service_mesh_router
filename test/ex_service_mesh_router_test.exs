defmodule ExServiceMeshRouterTest do
  use ExUnit.Case
  use Plug.Test

  alias ExServiceMeshRouter.Routing.AppRouter
  alias ExServiceMeshRouter.Routing.TopicRouter
  alias ExServiceMeshRouter.Discovery.{AutoRegistry, ManifestStore}
  alias ExServiceMeshRouter.TestHelpers

  import ExServiceMeshRouter.TestHelpers

  # ============================================================
  # BOOTSTRAP SYSTEM STATE
  # ============================================================

  setup do
    AutoRegistry.register(:app_a, %{
      host: "localhost",
      port: 4001,
      ws_path: "/socket/websocket"
    })

    ManifestStore.update(:app_a, sample_manifest())

    :ok
  end

  # ============================================================
  # HTTP ENTRYPOINT INTEGRATION
  # ============================================================

  test "routes HTTP request through full mesh pipeline" do
    conn =
      conn(:get, "/apps/app_a/api/users")
      |> put_req_header("host", "localhost")
      |> AppRouter.route()

    assert conn.status == 202
    assert conn.resp_body == "accepted"
  end

  # ============================================================
  # HTTP INVALID ROUTE REJECTION
  # ============================================================

  test "rejects unknown HTTP route at system boundary" do
    conn =
      conn(:get, "/apps/app_a/does/not/exist")
      |> put_req_header("host", "localhost")
      |> AppRouter.route()

    assert conn.status == 404
  end

  # ============================================================
  # WS ENTRYPOINT INTEGRATION
  # ============================================================

  test "routes WS topic through full mesh pipeline" do
    assert {:ok, ctx} =
             TopicRouter.route(:app_a, "room:lobby", %{
               msg: "hello"
             })

    assert ctx.app == :app_a
    assert ctx.path == "room:lobby"
  end

  # ============================================================
  # WS INVALID TOPIC
  # ============================================================

  test "rejects invalid WS topic at system boundary" do
    assert {:error, :topic_not_allowed} =
             TopicRouter.route(:app_a, "invalid:topic", %{})
  end

  # ============================================================
  # DISCOVERY + MANIFEST CONSISTENCY
  # ============================================================

  test "manifest-driven routing consistency across system" do
    {:ok, manifest} = ManifestStore.get(:app_a)

    assert Map.has_key?(manifest, :http)
    assert Map.has_key?(manifest, :ws)
  end

  # ============================================================
  # AUTO REGISTRY CONSISTENCY
  # ============================================================

  test "registry resolves app endpoints correctly" do
    {:ok, endpoint} = AutoRegistry.lookup(:app_a)

    assert endpoint.host == "localhost"
    assert endpoint.port == 4001
  end

  # ============================================================
  # FULL SYSTEM INTEGRATION SIMULATION
  # ============================================================

  test "simulated end-to-end request lifecycle" do
    # 1. resolve app
    {:ok, endpoint} = AutoRegistry.lookup(:app_a)

    # 2. fetch manifest
    {:ok, manifest} = ManifestStore.get(:app_a)

    # 3. build HTTP context
    ctx =
      %ExServiceMeshRouter.Routing.Context{
        app: :app_a,
        endpoint: endpoint,
        manifest: manifest.manifest,
        path: "/api/users",
        method: "GET",
        type: :http,
        event: %{host: "localhost"},
        assigns: %{},
        errors: []
      }

    # 4. validate routing
    assert :ok =
             ExServiceMeshRouter.Routing.Validation.validate(ctx)

    # 5. ensure system coherence
    assert ctx.app == :app_a
    assert ctx.endpoint.port == 4001
    assert ctx.manifest.http["/api/users"] == ["GET", "POST"]
  end

  # ============================================================
  # SYSTEM INVARIANTS
  # ============================================================

  test "system maintains routing invariants" do
    {:ok, manifest} = ManifestStore.get(:app_a)

    # HTTP must exist
    assert map_size(manifest.manifest.http) > 0

    # WS must exist
    assert length(manifest.manifest.ws.topics) > 0

    # registry must resolve
    assert {:ok, _} = AutoRegistry.lookup(:app_a)
  end
end