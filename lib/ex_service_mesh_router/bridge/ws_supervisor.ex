defmodule ExServiceMeshRouter.Bridge.WsSupervisor do
  @moduledoc """
  Supervises WS session bridges.
  """

  use DynamicSupervisor

  def start_link(_),
      do: DynamicSupervisor.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(opts) do
    spec = {ExServiceMeshRouter.Bridge.WsSession, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end