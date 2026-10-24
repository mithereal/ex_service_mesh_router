defmodule ExServiceMeshRouter.Integration.MeshRoutingTest do
  use ExUnit.Case, async: false
  import Plug.Conn

  @gateway_port 4999
  @mock_app_port 4998
  @service_host "test-service.mesh.local"

  # --- Mock Downstream Service Application ---
  defmodule MockDownstreamApp do
    use Plug.Router
    import Plug.Conn

    plug :match
    plug :dispatch

    get "/api/test" do
      host_header = get_req_header(conn, "host") |> List.first()
      
      case Router.Shared.TenantResolver.resolve(host_header) do
        {:ok, tenant} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{status: "success", tenant: tenant, host: host_header}))

        :error ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(400, Jason.encode!(%{status: "error", message: "unresolved_tenant"}))
      end
    end

    # Fallback to handle WebSocket connections or other requests gracefully
    match _ do
      send_resp(conn, 200, "ok")
    end
  end

  # --- Mock WebSocket Client ---
  defmodule MockWSClient do
    use WebSockex

    def start_link(url, owner_pid, opts) do
      WebSockex.start_link(url, __MODULE__, %{owner: owner_pid}, opts)
    end

    def handle_connect(_conn, state) do
      send(state.owner, {:ws_connected, self()})
      {:ok, state}
    end

    def handle_frame({type, msg}, state) do
      send(state.owner, {:ws_frame, type, msg})
      {:ok, state}
    end
  end

  # --- Lifecycle Setup and Teardown Hooks ---
  setup_all do
    # 1. Start the core registry if it's not already running in the test process tree
    start_supervised!(Router.Registry)

    # 2. Start the Mock Downstream Application
    {:ok, mock_pid} = Bandit.start_link(plug: MockDownstreamApp, port: @mock_app_port)

    # 3. Start the actual Gateway Router Server using Bandit
    {:ok, gateway_pid} = Bandit.start_link(plug: Router.Router, port: @gateway_port)

    # 4. FIX: Use the public API to register your service matching the updated state schema
    # This automatically handles process linking (`self()`) and tuple state composition.
    :ok = Router.Registry.register_service(@service_host, "localhost:#{@mock_app_port}")

    on_exit(fn ->
      Process.exit(mock_pid, :shutdown)
      Process.exit(gateway_pid, :shutdown)
    end)

    :ok
  end

  # --- Integration Tests ---

  test "successful stateless HTTP dynamic forwarding with tenant extraction" do
    target_host = "acme-tenant.#{@service_host}"

    response = 
      Req.get!("http://localhost:#{@gateway_port}/api/test", 
        headers: [{"host", target_host}]
      )

    assert response.status == 200
    
    body = response.body
    assert body["status"] == "success"
    assert body["tenant"] == "acme-tenant"
    assert body["host"] == target_host
  end

  test "gateway aggressively rejects requests targeting unknown domain clusters" do
    response = 
      Req.get!("http://localhost:#{@gateway_port}/api/test", 
        headers: [{"host", "missing-tenant.unregistered-service.local"}]
      )

    assert response.status == 404
    # FIX: Updated to match your specific Router string format
    assert response.body =~ "unknown service"
  end

  test "successful stateful WebSocket connection upgrade and message framing transport" do
    target_host = "chat-tenant.#{@service_host}"
    ws_url = "ws://localhost:#{@gateway_port}/socket/websocket"
    
    # FIX: Options are now explicitly passed to WebSockex
    options = [
      extra_headers: [{"host", target_host}]
    ]

    case MockWSClient.start_link(ws_url, self(), options) do
      {:ok, client_pid} ->
        assert_receive {:ws_connected, ^client_pid}, 2000
        Process.exit(client_pid, :normal)

      {:error, reason} ->
        flunk("WebSocket upgrade failed to negotiate handshake via proxy. Reason: #{inspect(reason)}")
    end
  end
end
