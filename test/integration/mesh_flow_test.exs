defmodule ExServiceMeshRouter.Integration.MeshFlowTest do
  use ExUnit.Case
  use Plug.Test

  alias ExServiceMeshRouter.Discovery.{AutoRegistry, ManifestStore}
  alias ExServiceMeshRouter.Routing.{AppRouter, TopicRouter, Context}
  alias ExServiceMeshRouter.Protocol.{Builder, Validator}
  alias ExServiceMeshRouter.TestHelpers

  import ExServiceMeshRouter.TestHelpers

  setup do
    # -------------------------
    # bootstrap app into mesh
    # -------------------------
    AutoRegistry.register(:app_a, %{
      host: "localhost",
      port: 4001,
      ws_path: "/socket/websocket"
    })

    ManifestStore.update(:app_a, sample_manifest())

    :ok
  end

  # ============================================================
  # HTTP FULL FLOW TEST
  # ============================================================

  test "full HTTP routing lifecycle through mesh" do
    conn =
      conn(:get, "/apps/app_a/api/users")
      |> put_req_header("host", "localhost")
      |> AppRouter.route()

    assert conn.status == 202
    assert conn.resp_body == "accepted"
  end

  # ============================================================
  # INVALID HTTP ROUTE REJECTION
  # ============================================================

  test "rejects invalid HTTP route at validation layer" do
    conn =
      conn(:get, "/apps/app_a/invalid/path")
      |> put_req_header("host", "localhost")
      |> AppRouter.route()

    assert conn.status == 404
  end

  # ============================================================
  # WS TOPIC FLOW
  # ============================================================

  test "WS topic routing passes through full validation pipeline" do
    assert {:ok, ctx} =
             TopicRouter.route(:app_a, "room:lobby", %{
               message: "hello"
             })

    assert ctx.app == :app_a
    assert ctx.assigns.topic == "room:lobby"
  end

  # ============================================================
  # INVALID WS TOPIC
  # ============================================================

  test "rejects invalid WS topic" do
    assert {:error, :topic_not_allowed} =
             TopicRouter.route(:app_a, "bad:topic", %{})
  end

  # ============================================================
  # CONTEXT VALIDATION FLOW
  # ============================================================

  test "context validates HTTP route correctly" do
    ctx = %Context{
      manifest: sample_manifest(),
      path: "/api/users",
      method: "GET",
      event: %{host: "localhost"},
      type: :http
    }

    assert Context.http_allowed?(ctx) == true
  end

  # ============================================================
  # PROTOCOL BUILD + VALIDATION
  # ============================================================

  test "protocol frame builds and validates correctly" do
    event = %ExServiceMeshRouter.Core.MeshEvent{
      type: :http,
      app: :app_a,
      path: "/api/users",
      method: "GET",
      headers: %{},
      payload: %{}
    }

    frame = Builder.from_event(event)

    assert :ok = Validator.validate(frame)
    assert frame.app == :app_a
    assert frame.type == :http
  end

  # ============================================================
  # FULL END-TO-END FLOW (SIMULATED PIPELINE)
  # ============================================================

  test "simulated full mesh pipeline flow" do
    # 1. resolve app
    {:ok, endpoint} = AutoRegistry.lookup(:app_a)

    # 2. fetch manifest
    {:ok, manifest} = ManifestStore.get(:app_a)

    # 3. build event
    event = sample_event(:app_a)

    # 4. build context
    ctx =
      Context.new(event, :app_a, endpoint, manifest)

    # 5. validate
    assert :ok = ExServiceMeshRouter.Routing.Validation.validate(ctx)

    # 6. ensure context is consistent
    assert ctx.app == :app_a
    assert ctx.endpoint.port == endpoint.port
  end
end