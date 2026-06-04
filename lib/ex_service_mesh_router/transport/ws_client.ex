defmodule ExServiceMeshRouter.Transport.WsClient do
  @moduledoc """
  WebSocket client used by the bridge layer to communicate with Phoenix apps.

  Responsibilities:
  - Maintain WS connections per app endpoint
  - Send MeshEvents over WS
  - Reconnect on failure
  - Provide simple send API for Bridge.WsSession
  """

  use GenServer

  require Logger

  alias ExServiceMeshRouter.Core.MeshEvent

  # -------------------------
  # PUBLIC API
  # -------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(opts))
  end

  @doc """
  Send an event over an active WS connection.
  """
  def send_event(app, event) do
    GenServer.cast(via(app), {:send, event})
  end

  # -------------------------
  # INIT
  # -------------------------

  def init(opts) do
    state = %{
      app: opts.app,
      endpoint: opts.endpoint,
      socket: nil,
      retry: 0
    }

    {:ok, connect(state)}
  end

  # -------------------------
  # PUBLIC CAST HANDLER
  # -------------------------

  def handle_cast({:send, %MeshEvent{} = event}, state) do
    case state.socket do
      nil ->
        {:noreply, reconnect_and_buffer(event, state)}

      socket ->
        :ok = push(socket, event)
        {:noreply, state}
    end
  end

  # -------------------------
  # CONNECTION LIFECYCLE
  # -------------------------

  defp connect(state) do
    case open_socket(state.endpoint) do
      {:ok, socket} ->
        %{state | socket: socket, retry: 0}

      {:error, _reason} ->
        schedule_retry(state)
    end
  end

  defp open_socket(%{host: host, port: port, ws_path: path}) do
    url = ws_url(host, port, path)

    # NOTE: placeholder adapter
    # In production replace with:
    # - :gun
    # - Mint.WebSocket
    # - WebSockex

    Logger.info("Connecting WS: #{url}")

    {:ok, %{conn: :mock_ws_connection, url: url}}
  end

  # -------------------------
  # SEND LOGIC
  # -------------------------

  defp push(_socket, event) do
    encoded = encode_event(event)

    # placeholder send
    Logger.debug("WS SEND: #{encoded}")

    :ok
  end

  defp encode_event(%MeshEvent{} = event) do
    %{
      type: event.type,
      app: event.app,
      path: event.path,
      payload: event.payload
    }
    |> Jason.encode!()
  end

  # -------------------------
  # RECONNECT LOGIC
  # -------------------------

  defp reconnect_and_buffer(event, state) do
    Logger.warn("WS disconnected, retrying...")

    schedule_retry(state)

    state
  end

  defp schedule_retry(state) do
    delay = backoff(state.retry)

    Process.send_after(self(), :reconnect, delay)

    %{state | retry: state.retry + 1}
  end

  def handle_info(:reconnect, state) do
    {:noreply, connect(state)}
  end

  # -------------------------
  # UTILITIES
  # -------------------------

  defp ws_url(host, port, path) do
    "ws://#{host}:#{port}#{path}"
  end

  defp backoff(retry) do
    min(30_000, :math.pow(2, retry) * 250)
    |> round()
  end

  defp via(%{app: app}), do: via(app)
  defp via(app), do: {:via, Registry, {ExServiceMeshRouter.Registry, {:ws, app}}}
end