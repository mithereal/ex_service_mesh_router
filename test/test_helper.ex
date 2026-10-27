# 1. Start the core ExUnit testing framework engine
ExUnit.start()
ExUnit.start(async: false)

# =====================================================================
# 2. Multi-Framework Testing Stubs & Mock Definitions
# =====================================================================

defmodule Router.Integration.MockRepo do
  @moduledoc """
  Mock Ecto Repository adapter designed to capture process telemetry mutations
  during multi-tenant testing cycles.
  """
  def put_tenant(tenant) do
    # Bind the tenant token onto the active test process dictionary thread context
    Process.put(:mock_ecto_tenant, tenant)
    :ok
  end

  def get_tenant do
    Process.get(:mock_ecto_tenant)
  end
end

defmodule Router.Integration.MockEndpoint do
  @moduledoc """
  Stub Phoenix Endpoint required by ClusterLifecycleWorker reflection tests.
  """
  def config(:url), do: [host: "test-service.mesh.local"]
  def config(:http), do: [port: 4998]
  def config(_), do: []
end

# =====================================================================
# 3. Global Test Environment Configurations Override
# =====================================================================

# Enforce test ports and mock module configurations dynamically across dependencies
Application.put_env(:ex_service_mesh_router, Router.Router, http_port: 4999)

Application.put_env(:router_shared, :app_name, :auth_app)
Application.put_env(:router_shared, :gateway_node, Node.self())
Application.put_env(:router_shared, :enable_ecto_tenant, true)
Application.put_env(:router_shared, :ecto_repo, Router.Integration.MockRepo)
Application.put_env(:router_shared, :enable_ash_tenant, false)

Application.put_env(:auth_app, :endpoint, Router.Integration.MockEndpoint)

# =====================================================================
# 4. Distributed BEAM Handshake Emulation Layer
# =====================================================================

# Automatically spin up Erlang distribution for the test suite execution context 
# to shield ClusterLifecycleWorker tests against :noconnection alerts.
case Node.alive?() do
  false ->
    IO.puts(
      "\033[0;32m[Test Setup]\033[0m Initializing local shortname distributed node environment..."
    )

    # Converts this test runner instance into a visible cluster participant
    {:ok, _pid} = :net_kernel.start([:"test_runner@127.0.0.1", :shortnames])

    # Enforce standard cookie configuration parity matching Docker/Prod spaces
    Node.set_cookie(:mesh_secure_token_123)

  true ->
    :ok
end
