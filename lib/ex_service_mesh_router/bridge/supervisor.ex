defmodule ExServiceMeshRouter.Bridge.Supervisor do
  @moduledoc """
  Supervises bridge workers responsible for WS and HTTP forwarding.
  """

  use Supervisor

  def start_link(_),
      do: Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    children = [
      ExServiceMeshRouter.Bridge.HttpForwarder,
      ExServiceMeshRouter.Bridge.WsSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end