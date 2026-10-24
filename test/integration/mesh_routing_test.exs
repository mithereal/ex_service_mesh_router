defmodule ExServiceMeshRouter.Integration.MeshRoutingTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Phoenix.LiveViewTest

  @gateway_port 4999
  @mock_app_port 4998
  @service_host "test-service.mesh.local"

  # --- Mock Downstream Service Application ---
  defmodule MockDownstreamApp do
    use Plug.Router
    use Phoenix.Component

    # Required for rendering LiveViews inside the test harness
    import Phoenix.LiveView.Router

    plug :match
    plug :dispatch

    # Define a standard router scope for testing LiveView mount behaviors
    live_session :secure_mesh_session, on_mount: [{Router.Shared.Hooks.TenantLiveMount, :default}] do
      live "/live-test", MockLiveView
    end

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

    match _ do
      send_resp(conn, 200, "ok")
    end
  end

  # --- Mock Downstream LiveView Component ---
  defmodule MockLiveView do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <div id="live-workspace">Tenant Workspace: <%= @tenant %></div>
      """
    end

    def handle_params(_params, _uri, socket) do
      {:noreply, socket}
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

  # --- Test Setup Context ---
  setup do
    # 1. Start the core registry safely isolated within this specific test process scope
    _registry_pid = start_supervised!({Router.Registry, name: Router.Registry})

    # 2. Start the Mock Downstream Application supervised
    _mock_pid = start_supervised!({Bandit, plug: MockDownstreamApp, port: @mock_app_port})

    # 3. Start the Ingress Gateway Router Server supervised
    _gateway_pid = start_supervised!({Bandit, plug: Router.Router, port: @gateway_port})

    # 4. Invoke the public API to bind the service topology mapping
    :ok = Router.Registry.register_service(@service_host, "localhost:#{@mock_app_port}")

    # Set up basic Phoenix endpoint test environment details if required by LiveViewTest
    @endpoint MockDownstreamApp
    {:ok, conn: Plug.Test.conn()}
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
    assert response.body =~ "unknown service"
  end

  test "successful stateful WebSocket connection upgrade and message framing transport" do
    target_host = "chat-tenant.#{@service_host}"
    ws_url = "ws://localhost:#{@gateway_port}/socket/websocket"
    
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

  # --- NEW: X-Backplane-Service Override Bypass Test ---

  test "X-Backplane-Service header completely bypasses edge host subdomain slicing" do
    # Even though the host header format points to an invalid structure that would 
    # normally break parsing, the explicit presence of the backplane header forces 
    # the gateway router to evaluate the raw service registration path directly.
    response = 
      Req.get!("http://localhost:#{@gateway_port}/api/test", 
        headers: [
          {"host", "invalid-format-subdomain"},
          {"x-backplane-service", @service_host}
        ]
      )

    # Assert that it successfully bypasses slicing, resolves the host, and forwards down-stream
    assert response.status == 200
  end

  # --- NEW: TenantLiveMount Hook Lifecyle Guard Test ---

  test "TenantLiveMount hook successfully executes context mapping or halts unscoped sessions", %{conn: conn} do
    # Scenario A: Connection attempts mounting with a populated session workspace mapping
    scoped_session = %{"tenant" => "company-abc"}
    
    {:ok, _view, html} = 
      live_isolated(conn, MockLiveView, session: scoped_session)
    
    assert html =~ "Tenant Workspace: company-abc"

    # Scenario B: Connection attempts mounting with an empty session workspace context
    unscoped_session = %{}
    
    # Assert that the lifecycle guard catch forces a halt and issues a safe redirect
    assert {:error, {:redirect, %{to: "/error-invalid-tenant"}}} = 
             live_isolated(conn, MockLiveView, session: unscoped_session)
  end
end
