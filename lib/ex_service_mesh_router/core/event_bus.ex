defmodule ExServiceMeshRouter.Core.EventBus do
  @moduledoc """
  Central dispatch point for normalized MeshEvents.

  Routes events into the pipeline system based on type.
  """

  use GenServer

  def start_link(_),
      do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def emit(event),
      do: GenServer.cast(__MODULE__, {:event, event})

  def init(state),
      do: {:ok, state}

  def handle_cast({:event, event}, state) do
    pipeline =
      case event.type do
        :ws -> :ws_pipeline
        :http -> :routing_pipeline
      end

    ExServiceMeshRouter.Pipeline.Engine.run(event, pipeline)

    {:noreply, state}
  end
end