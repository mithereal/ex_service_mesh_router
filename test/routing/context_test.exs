defmodule ExServiceMeshRouter.Routing.ContextTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Routing.Context
  alias ExServiceMeshRouter.TestHelpers

  import ExServiceMeshRouter.TestHelpers

  # ============================================================
  # BUILD CONTEXT
  # ============================================================

  test "builds context from event" do
    event = sample_event(:app_a)

    ctx =
      Context.new(
        event,
        :app_a,
        %{host: "localhost", port: 4001},
        sample_manifest()
      )

    assert ctx.app == :app_a
    assert ctx.path == "/api/users"
    assert ctx.method == "GET"
  end

  # ============================================================
  # HTTP VALIDATION SUCCESS
  # ============================================================

  test "http_allowed? returns true for valid route" do
    ctx =
      build_http_ctx("/api/users", "GET")

    assert Context.http_allowed?(ctx) == true
  end

  # ============================================================
  # HTTP VALIDATION FAILURE
  # ============================================================

  test "http_allowed? returns false for invalid route" do
    ctx =
      build_http_ctx("/invalid", "GET")

    assert Context.http_allowed?(ctx) == false
  end

  # ============================================================
  # METHOD VALIDATION FAILURE
  # ============================================================

  test "http_allowed? rejects invalid method" do
    ctx =
      build_http_ctx("/api/users", "DELETE")

    assert Context.http_allowed?(ctx) == false
  end

  # ============================================================
  # DOMAIN VALIDATION
  # ============================================================

  test "domain_allowed? passes when domain matches" do
    ctx =
      %Context{
        manifest: sample_manifest(),
        event: %{host: "localhost"}
      }

    assert Context.domain_allowed?(ctx) == true
  end

  test "domain_allowed? fails when domain mismatch" do
    ctx =
      %Context{
        manifest: sample_manifest(),
        event: %{host: "evil.local"}
      }

    assert Context.domain_allowed?(ctx) == false
  end

  # ============================================================
  # WS VALIDATION
  # ============================================================

  test "ws_allowed? passes valid topic" do
    ctx =
      %Context{
        manifest: sample_manifest(),
        path: "room:lobby",
        event: %{host: "localhost"}
      }

    assert Context.ws_allowed?(ctx) == true
  end

  test "ws_allowed? rejects invalid topic" do
    ctx =
      %Context{
        manifest: sample_manifest(),
        path: "bad:topic",
        event: %{host: "localhost"}
      }

    assert Context.ws_allowed?(ctx) == false
  end

  # ============================================================
  # ASSIGN MUTATION
  # ============================================================

  test "assign adds metadata to context" do
    ctx =
      build_http_ctx("/api/users", "GET")
      |> Context.assign(:trace_id, "abc123")

    assert ctx.assigns.trace_id == "abc123"
  end

  # ============================================================
  # ERROR ACCUMULATION
  # ============================================================

  test "add_error accumulates errors" do
    ctx =
      build_http_ctx("/api/users", "GET")
      |> Context.add_error(:something_failed)
      |> Context.add_error(:another_error)

    assert length(ctx.errors) == 2
  end

  # ============================================================
  # HALT STATE
  # ============================================================

  test "halt marks context as halted" do
    ctx =
      build_http_ctx("/api/users", "GET")
      |> Context.halt()

    assert ctx.halted == true
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp build_http_ctx(path, method) do
    %Context{
      manifest: sample_manifest(),
      path: path,
      method: method,
      type: :http,
      event: %{host: "localhost"}
    }
  end
end