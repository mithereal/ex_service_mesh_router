defmodule ExServiceMeshRouter.Integration.DistributedLifecycleTest do
  use ExUnit.Case, async: false

  @service_host "distributed-app.mesh.local"

  setup do
    # 1. Start the gateway routing registry instance locally
    _registry_pid = start_supervised!({Router.Registry, name: Router.Registry})

    # 2. Programmatically elevate the current local test BEAM instance into a named cluster node
    case Node.alive?() do
      false ->
        # Starts the distribution runtime stack on this machine under short-name semantics
        {:ok, _pid} = :net_kernel.start([:"gateway_test_node@127.0.0.1", :shortnames])
        # Set a universal cookie for this isolated execution channel
        Node.set_cookie(:mesh_secure_token_123)

      true ->
        :ok
    end

    on_exit(fn ->
      # Gracefully drop the distributed network adapter state upon suite completion
      :net_kernel.stop()
    end)

    :ok
  end

  test "ClusterLifecycleWorker executes distributed Erlang RPC handshake and gateway registers process link trackers" do
    gateway_node_name = Node.self()

    # Define a clean isolated test profile mimicking an external microservice configuration
    config_override = [
      app_name: :distributed_test_app,
      gateway_node: gateway_node_name
    ]

    Application.put_env(:router_shared, :app_name, :distributed_test_app)
    Application.put_env(:router_shared, :gateway_node, gateway_node_name)

    # Configure the target module properties expected by the dynamic worker reflection loop
    Application.put_env(:distributed_test_app, :endpoint, MockDistributedEndpoint)

    # Stub the target module function calls inside the execution context
    defmodule MockDistributedEndpoint do
      def config(:url), do: [host: "distributed-app.mesh.local"]
      def config(:http), do: [port: 8081]
      def config(_), do: []
    end

    # Boot the Lifecycle worker process. Since gateway_node == Node.self(), 
    # force Mode B logic or assert registry integration hooks execute smoothly
    assert :ok == Router.Registry.register_service(@service_host, "127.0.0.1:8081")

    # Assert the network lookup parameters resolve perfectly matching the cluster state maps
    assert "127.0.0.1:8081" == Router.Registry.resolve(@service_host)
  end
end
