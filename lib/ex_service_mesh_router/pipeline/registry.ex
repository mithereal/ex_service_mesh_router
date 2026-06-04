defmodule ExServiceMeshRouter.Pipeline.Registry do
  @moduledoc """
  Runtime registry for routing pipelines.

  Allows dynamic injection and replacement of routing behavior.
  """

  use GenServer

  def start_link(_),
      do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    state = %{
      routing_pipeline: default_http_pipeline(),
      ws_pipeline: default_ws_pipeline()
    }

    {:ok, state}
  end

  def get(name),
      do: GenServer.call(__MODULE__, {:get, name})

  def set(name, stages),
      do: GenServer.cast(__MODULE__, {:set, name, stages})

  def handle_call({:get, name}, _from, state),
      do: {:reply, Map.get(state, name, []), state}

  def handle_cast({:set, name, stages}, state),
      do: {:noreply, Map.put(state, name, stages)}

  defp default_http_pipeline do
    [
      ExServiceMeshRouter.Pipeline.Stages.Normalize,
      ExServiceMeshRouter.Pipeline.Stages.ResolveApp,
      ExServiceMeshRouter.Pipeline.Stages.Route
    ]
  end

  defp default_ws_pipeline do
    [
      ExServiceMeshRouter.Pipeline.Stages.Normalize,
      ExServiceMeshRouter.Pipeline.Stages.ResolveApp,
      ExServiceMeshRouter.Pipeline.Stages.Route
    ]
  end
end