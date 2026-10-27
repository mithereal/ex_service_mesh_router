defmodule Router.Shared.ClusterLifecycleWorker do
  use GenServer
  require Logger

  @moduledoc """
  Automatically registers the host application's Phoenix Endpoint with the 
  central `Router.Registry`, supporting both local umbrella and multi-node environments.
  """

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    # Read the designated gateway node from configuration, defaulting to local node
    gateway_node =
      Keyword.get(opts, :gateway_node) ||
        Application.get_env(:router_shared, :gateway_node, Node.self())

    state = %{
      gateway_node: gateway_node,
      timer_ref: nil
    }

    # Trigger registration asynchronously immediately after the application boots up
    send(self(), :announce_to_gateway)
    {:ok, state}
  end

  @impl true
  def handle_info(:announce_to_gateway, state) do
    # Cancel any outstanding retry timers to avoid race conditions
    state = cancel_retry_timer(state)

    cond do
      # Mode A: Gateway runs on the exact same node (Local Umbrella / Non-Distributed)
      state.gateway_node == Node.self() ->
        register_locally()
        {:noreply, state}

      # Mode B: Gateway runs on a separate connected node (Distributed / Multi-Node Cluster)
      state.gateway_node in Node.list() ->
        register_remotely(state.gateway_node)
        {:noreply, state}

      # Mode C: Node is disconnected or gateway node is not visible yet
      true ->
        Logger.warning(
          "[Mesh Network] Gateway node #{inspect(state.gateway_node)} is not visible. Retrying in 5 seconds..."
        )

        timer_ref = Process.send_after(self(), :announce_to_gateway, 5000)
        {:noreply, %{state | timer_ref: timer_ref}}
    end
  end

  # --- Internal Registration Helpers ---

  defp register_locally do
    # If in a single local umbrella, Router.Registry discovers endpoints automatically via its own loop,
    # but running a manual fallback execution here guarantees registration table alignment.
    case fetch_endpoint_details() do
      {:ok, host, upstream_address} ->
        if Process.whereis(Router.Registry) do
          _ = Router.Registry.register_service(host, upstream_address)

          Logger.info(
            "[Mesh Network] Verified local registration for service '#{host}' -> #{upstream_address}"
          )
        end

      :error ->
        :ok
    end
  end

  defp register_remotely(gateway_node) do
    case fetch_endpoint_details() do
      {:ok, host, upstream_address} ->
        # Perform an Erlang RPC network call straight into the central gateway's Registry GenServer process.
        # Erlang explicitly tracks the calling process ID (`self()`) across the RPC layer,
        # allowing the gateway's `Process.link/1` hook to attach to this remote process automatically.
        case :rpc.call(gateway_node, Router.Registry, :register_service, [host, upstream_address]) do
          :ok ->
            Logger.info(
              "[Mesh Network] Successfully announced route via RPC to gateway node #{inspect(gateway_node)}: '#{host}' -> #{upstream_address}"
            )

          error ->
            Logger.error(
              "[Mesh Network] Failed to announce route to remote gateway. Reason: #{inspect(error)}"
            )
        end

      :error ->
        Logger.error(
          "[Mesh Network] Cannot register service: local application endpoint configuration is missing."
        )
    end
  end

  defp fetch_endpoint_details do
    # Dynamic application lookup looks for the designated endpoint registered in the current application environment
    app_name = Application.get_env(:router_shared, :app_name)

    case Application.get_env(app_name, :endpoint) do
      nil ->
        :error

      endpoint_module ->
        if Code.ensure_loaded?(endpoint_module) do
          # 1. Resolve host key configuration
          url_config = endpoint_module.config(:url) || []
          host = Keyword.get(url_config, :host)

          # 2. Resolve IP and Port layout
          http_config = endpoint_module.config(:http) || []
          port = Keyword.get(http_config, :port) || 4000

          # Use an environment IP variable if deployed on a multi-node docker/cloud network
          local_ip = System.get_env("NODE_IP") || "localhost"

          if host do
            {:ok, host, "#{local_ip}:#{port}"}
          else
            :error
          end
        else
          :error
        end
    end
  end

  defp cancel_retry_timer(%{timer_ref: nil} = state), do: state

  defp cancel_retry_timer(%{timer_ref: ref} = state) do
    _ = Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end
end
