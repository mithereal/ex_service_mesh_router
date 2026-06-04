defmodule Router.Registry do
  use GenServer

  @moduledoc """
  Service-level registry only (NO tenant logic).
  """

  def start_link(_),
    do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def resolve(host),
    do: GenServer.call(__MODULE__, {:resolve, host})

  def init(_) do
    {:ok, discover_services()}
  end

  def handle_call({:resolve, host}, _from, state) do
    {:reply, Map.get(state, host), state}
  end

  defp discover_services do
    Application.loaded_applications()
    |> Enum.flat_map(fn {app, _, _} ->
      endpoint = Application.get_env(app, :endpoint)

      if endpoint do
        url =
          Application.get_env(app, endpoint, [])
          |> Keyword.get(:url, [])

        host = Keyword.get(url, :host)

        if host, do: [{host, endpoint}], else: []
      else
        []
      end
    end)
    |> Map.new()
  end
end
