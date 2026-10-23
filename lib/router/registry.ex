defmodule Router.Registry do
  use GenServer

  @moduledoc """
  Service-level registry only (NO tenant logic).
  """

  def start_link(_),
    do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def resolve(service_host),
    do: GenServer.call(__MODULE__, {:resolve, service_host})

  def init(_) do
    # FIX: Boot instantly. Discover asynchronously to avoid boot-time race conditions.
    send(self(), :discover_services)
    {:ok, %{}}
  end

  def handle_call({:resolve, service_host}, _from, state) do
    {:reply, Map.get(state, service_host), state}
  end

  def handle_info(:discover_services, _state) do
    {:noreply, fetch_service_mappings()}
  end

  defp fetch_service_mappings do
    Application.loaded_applications()
    |> Enum.flat_map(fn {app, _, _} ->
      # FIX: Fetch config out of the running application's environment block
      case Application.get_env(app, :endpoint) do
        nil -> 
          []

        endpoint ->
          url_config = Application.get_env(app, endpoint, [])
          host = Keyword.get(url_config, :url, []) |> Keyword.get(:host)
          
          if host, do: [{host, endpoint}], else: []
      end
    end)
    |> Map.new()
  end
end
