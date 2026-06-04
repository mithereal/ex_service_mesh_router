defmodule ExServiceMeshRouter.TestHelpers do
  @moduledoc """
  Shared test utilities for the service mesh router test suite.

  Provides:
  - sample manifests
  - sample events
  - context builders
  - endpoint builders
  - reusable routing fixtures
  """

  alias ExServiceMeshRouter.Routing.Context
  alias ExServiceMeshRouter.Core.MeshEvent

  # ============================================================
  # SAMPLE MANIFEST
  # ============================================================

  def sample_manifest do
    %{
      http: %{
        "/api/users" => ["GET", "POST"],
        "/api/health" => ["GET"]
      },
      ws: %{
        topics: [
          "room:*",
          "user:*",
          "admin:*"
        ]
      },
      domains: [
        "localhost",
        "127.0.0.1"
      ]
    }
  end

  # ============================================================
  # SAMPLE EVENTS
  # ============================================================

  def sample_event(app \\ :app_a) do
    %MeshEvent{
      type: :http,
      app: app,
      path: "/api/users",
      method: "GET",
      headers: %{
        "host" => "localhost"
      },
      payload: %{
        "hello" => "world"
      }
    }
  end

  def sample_ws_event(app \\ :app_a, topic \\ "room:lobby") do
    %MeshEvent{
      type: :ws,
      app: app,
      path: topic,
      method: nil,
      headers: %{},
      payload: %{
        msg: "hello"
      }
    }
  end

  # ============================================================
  # SAMPLE ENDPOINTS
  # ============================================================

  def sample_endpoint(app \\ :app_a, port \\ 4001) do
    %{
      host: "localhost",
      port: port,
      ws_path: "/socket/websocket",
      app: app
    }
  end

  # ============================================================
  # CONTEXT BUILDERS
  # ============================================================

  def build_http_ctx(path \\ "/api/users", method \\ "GET", app \\ :app_a) do
    %Context{
      app: app,
      endpoint: sample_endpoint(app),
      manifest: sample_manifest(),
      path: path,
      method: method,
      type: :http,
      event: %{host: "localhost"},
      assigns: %{},
      errors: []
    }
  end

  def build_ws_ctx(topic \\ "room:lobby", app \\ :app_a) do
    %Context{
      app: app,
      endpoint: sample_endpoint(app),
      manifest: sample_manifest(),
      path: topic,
      method: nil,
      type: :ws,
      event: %{host: "localhost"},
      assigns: %{},
      errors: []
    }
  end

  # ============================================================
  # VARIANT HELPERS
  # ============================================================

  def invalid_http_ctx do
    build_http_ctx("/invalid/path", "DELETE")
  end

  def invalid_ws_ctx do
    build_ws_ctx("bad:topic")
  end

  # ============================================================
  # MANIFEST VARIANTS
  # ============================================================

  def minimal_manifest do
    %{
      http: %{
        "/health" => ["GET"]
      },
      ws: %{
        topics: ["*"]
      },
      domains: ["localhost"]
    }
  end

  def empty_manifest do
    %{
      http: %{},
      ws: %{topics: []},
      domains: []
    }
  end

  # ============================================================
  # EDGE CASE HELPERS
  # ============================================================

  def malformed_event do
    %{
      type: :http,
      app: nil,
      path: nil,
      method: nil,
      headers: nil,
      payload: nil
    }
  end

  def high_load_events(count \\ 100) do
    for i <- 1..count do
      %MeshEvent{
        type: :http,
        app: :app_a,
        path: "/api/users/#{i}",
        method: "GET",
        headers: %{},
        payload: %{index: i}
      }
    end
  end

  # ============================================================
  # ASSERTION HELPERS
  # ============================================================

  def assert_valid_http_ctx(ctx) do
    assert ctx.type == :http
    assert ctx.app != nil
    assert ctx.manifest.http != %{}
  end

  def assert_valid_ws_ctx(ctx) do
    assert ctx.type == :ws
    assert is_binary(ctx.path)
  end
end