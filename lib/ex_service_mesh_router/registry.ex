defmodule Router.Registry do
  use GenServer
  require Logger

  @moduledoc """
  Service-level registry only (NO tenant logic).
  Supports local boot-time discovery AND dynamic cross-node cluster registration.
  """

  # --- Client API ---

  @doc """
  Starts the Registry GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: opts[:name] || __MODULE__)
  end

  @doc """
  Resolves a service host string (e.g., "auth.mesh.local") to an upstream network path.
  """
  def resolve(service_host) do
    GenServer.call(__MODULE__, {:resolve, service_host})
  end

  @doc """
  Public API invoked via Erlang RPC by remote nodes to announce their existence.
  """
  def register_service(host, upstream_address) do
    GenServer.call(__MODULE__, {:register, host, upstream_address})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    # CRITICAL FOR DISTRIBUTED NODES:
    # Traps system exit signals. Turns remote process/node crashes into a clean 
    # local :EXIT message payload instead of cascading a crash through the gateway.
    Process.flag(:trap_exit, true)

    # Trigger local umbrella application discovery asynchronously to avoid blocking boot
    send(self(), :discover_local_services)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:resolve, service_host}, _from, state) do
    {:reply, Map.get(state, service_host), state}
  end

  @impl true
  def handle_call({:register, host, upstream_address}, {from_pid, _}, state) do
    Logger.info("[Service Mesh Cluster] Dynamic node registration received from #{inspect(node(from_pid))}: '#{host}' -> #{upstream_address}")
    
    # Link to the calling remote process. If the remote node crashes or gets 
    # disconnected, this gateway process will receive an internal :EXIT message.
    Process.link(from_pid)
    
    # Store both the destination and the tracking pid of the worker node
    updated_state = Map.put(state, host, {upstream_address, from_pid})
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_info(:discover_local_services, state) do
    local_state = fetch_local_service_mappings()
    {:noreply, Map.merge(state, local_state)}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    dead_node = node(pid)
    Logger.warning("[Service Mesh Cluster] Node #{inspect(dead_node)} disconnected or crashed (Reason: #{inspect(reason)}). Pruning broken routes...")
    
    # Prune out any host maps that were bound to the process ID that just died
    cleaned_state = 
      Enum.reduce(state, %{}, fn 
        {host, {upstream_address, ^pid}}, acc -> 
          Logger.info("[Service Mesh Cluster] Deregistered route: '#{host}' -> #{upstream_address}")
          acc
        {host, val}, acc -> 
          Map.put(acc, host, val)
      end)

    {:noreply, cleaned_state}
  end

  # --- Internal Discovery Loops ---

  defp fetch_local_service_mappings do
    Application.loaded_applications()
    |> Enum.flat_map(fn {app, _, _} ->
      case Application.get_env(app, :endpoint) do
        nil -> 
          []

        endpoint_module ->
          if Code.ensure_loaded?(endpoint_module) do
            http_config = endpoint_module.config(:http) || []
            port = Keyword.get(http_config, :port) || 4000
            
            url_config = endpoint_module.config(:url) || []
            host = Keyword.get(url_config, :host)

            if host do
              upstream_url = "localhost:#{port}"
              Logger.info("[Service Mesh Discovery] Mapping local umbrella service host '#{host}' to: #{upstream_url}")
              # Local umbrella apps use self() as the tracking pid since they share the same OS process context
              [{host, {upstream_url, self()}}]
            else
              []
            end
          else
            []
          end
      end
    end)
    |> Map.new()
  end
end
