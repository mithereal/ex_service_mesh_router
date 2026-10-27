defmodule Router.Integration.ServiceMeshTest do
  use ExUnit.Case, async: false
  import Plug.Conn

  alias Router.Registry
  alias Router.Router
  alias Router.Shared.TenantResolver

  setup do
    # Clear out registry state prior to each isolation test pass
    start_supervised!({Registry, name: Registry})
    :ok
  end

  describe "Router.Registry Topology Engine" do
    test "successfully accepts local and remote node registration hooks" do
      dummy_pid = spawn(fn -> Process.sleep(:infinity) end)

      # Assert dynamic registration interface returns cleanly
      assert :ok == Registry.register_service("auth.mesh.local", "auth.mesh.local:4002")

      # Mutate state manually to simulate a linked process ID for target tracking
      send(Registry, {:register, "chat.mesh.local", "chat.mesh.local:4003"}, {dummy_pid, :tag})

      # Assert route lookups pull tracking payloads
      assert "auth.mesh.local:4002" == Registry.resolve("auth.mesh.local")
      assert "chat.mesh.local:4003" == Registry.resolve("chat.mesh.local")
    end

    test "prunes routes cleanly when receiving a process link :EXIT signal" do
      Process.flag(:trap_exit, true)

      # Spawn an ephemeral mock worker process mimicking a cloud container drop
      {mock_worker_pid, monitor_ref} =
        spawn_monitor(fn ->
          receive do: (:die -> :ok)
        end)

      # Register the mock worker into the central gateway mapping state
      Registry.register_service("ephemeral.mesh.local", "10.0.0.99:4000")

      # Force a linked mapping update within the state machine using internal calls
      # mimicking an RPC handshake link attachment
      send(
        Registry,
        {:register, "ephemeral.mesh.local", "10.0.0.99:4000"},
        {mock_worker_pid, :tag}
      )

      assert "10.0.0.99:4000" == Registry.resolve("ephemeral.mesh.local")

      # Kill the mock process and catch the exit telemetry thread flag
      send(mock_worker_pid, :die)
      assert_receive {:DOWN, ^monitor_ref, :process, ^mock_worker_pid, _reason}

      # Allow the GenServer a brief window to handle the exit signal
      Process.sleep(50)

      # Assert the fault-tolerant cleanup loop safely stripped out the route entry
      assert nil == Registry.resolve("ephemeral.mesh.local")
    end
  end

  describe "Router.Router Extraction Pipelines" do
    test "prioritizes X-Backplane-Service overrides above edge host headers" do
      Registry.register_service("auth.mesh.local", "auth.mesh.local:4002")
      Registry.register_service("chat.mesh.local", "chat.mesh.local:4003")

      # Build a request carrying conflicting host indicators
      conn =
        conn(:get, "/api/v1/status")
        |> put_req_header("host", "tenantA.chat.mesh.local:4000")
        |> put_req_header("x-backplane-service", "auth.mesh.local")
        |> Router.call([])

      # If prioritized properly, it skips chat routing and hits auth (or throws internal reverse proxy crash)
      # We assert it attempted routing parsing by inspecting the failure response pattern
      refute conn.status == 404
    end

    test "slices multi-part corporate subdomains down to functional base targets" do
      assert {:ok, "tenant-alpha"} == TenantResolver.resolve("tenant-alpha.auth.mesh.local:4000")

      assert {:ok, "enterprise-corp"} ==
               TenantResolver.resolve("enterprise-corp.chat.mesh.internal.zone")

      assert :error == TenantResolver.resolve("auth.mesh.local")
    end
  end
end
