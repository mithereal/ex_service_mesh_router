defmodule ExServiceMeshRouter.Bridge.WsSession do
  @moduledoc """
  Bridges a single WebSocket session between router and Phoenix app.
  """

  use GenServer

  alias ExServiceMeshRouter.Discovery.AutoRegistry

  def start_link(opts),
      do: GenServer.start_link(__MODULE__, opts)

  def init(opts) do
    {:ok, opts}
  end

  def handle_cast({:send, event}, state) do
    forward(event, state)
    {:noreply, state}
  end

  defp forward(event, %{app: app} = state) do
    case AutoRegistry.lookup(app) do
      {:ok, endpoint} ->
        url = ws_url(endpoint)

        send_ws(url, event.payload)

      _ ->
        :error
    end
  end

  defp ws_url(%{host: host, port: port, ws_path: path}) do
    "ws://#{host}:#{port}#{path}"
  end

  defp send_ws(_url, _payload) do
    # placeholder for actual WS client (Mint / Gun / WebSockex)
    :ok
  end
end