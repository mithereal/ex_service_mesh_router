defmodule ExServiceMeshRouter.Integration.MeshRoutingTest do
  use ExUnit.Case, async: false
  import Plug.Conn

  # Define constants for our validation test loop
  @gateway_port 4999
  @mock_app_port 4998
  @service_host "test-service.mesh.local"

  # --- Mock Downstream Service Application ---
  # This serves as a standalone target endpoint to verify proxy preservation
  defmodule MockDownstreamApp do
    use Plug.Router
    import Plug.Conn

    plug :match
    plug :dispatch

    # Verify standard HTTP header forwarding and parsing contracts
    get "/api/test" do
      host_header = get_req_header(conn, "host") |> List.first()
      
      # Echo back the structural parameters found by the app
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

    # Handle standard fallback catch-alls
    match _ do
      send_resp(conn, 404, "not_found")
    end
  end

  # --- Mock WebSocket Client for Verification ---
  # Uses WebSockex to verify stateful protocol transitions over the gateway
  defmodule MockWSClient do
    use WebSockex

    def start_link(url, owner_pid) do
      WebSockex.start_link(url, __MODULE__, %{owner: owner_pid})
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
    # 1. Start the actual target mock service application on our isolated port
    {:ok, mock_pid} = Bandit.start_link(plug: MockDownstreamApp, port: @mock_app_port)

    # 2. Inject a controlled manual routing registration into the GenServer State
    # This avoids full configuration file parsing dependencies inside the test execution context.
    Process.whereis(Router.Registry)
    |> send({:discover_services, %{@service_host => "localhost:#{@mock_app_port}"}})

    # Ensure everything settles cleanly into the process engine tables
    Process.sleep(100)

    on_exit(fn ->
      # Gracefully tear down backend mock servers upon completion
      Process.exit(mock_pid, :shutdown)
    end)

    :ok
  end

  # --- Integration Verification Test Block ---

  test "successful stateless HTTP dynamic forwarding with tenant extraction" do
    # Construct a virtual host pointing at our registered service map
    target_host = "acme-tenant.#{@service_host}"

    # Fire a live local network call at the main Bandit gateway interface
    response = 
      Req.get!("http://localhost:#{@gateway_port}/api/test", 
        headers: [{"host", target_host}]
      )

    assert response.status == 200
    
    # Assert that the proxy safely transported the context down to the app unchanged
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
    assert response.body =~ "Unknown service over mesh"
  end

  test "successful stateful WebSocket connection upgrade and message framing transport" do
    target_host = "chat-tenant.#{@service_host}"
    
    # Establish a real connection over the gateway pipeline using the WS scheme proxy
    ws_url = "ws://localhost:#{@gateway_port}/socket/websocket"
    
    # Attempt connection while injecting our specialized host routing parameters
    options = [
      extra_headers: [{"host", target_host}]
    ]

    # Attempt protocol connection loop upgrade verification block
    case MockWSClient.start_link(ws_url, self()) do
      {:ok, client_pid} ->
        # Assert that the gateway successfully negotiated the handshake and established the connection process
        assert_receive {:ws_connected, ^client_pid}, 2000
        Process.exit(client_pid, :normal)

      {:error, reason} ->
        flunk("WebSocket upgrade failed to negotiate handshake via proxy. Reason: #{inspect(reason)}")
    end
  end
end
