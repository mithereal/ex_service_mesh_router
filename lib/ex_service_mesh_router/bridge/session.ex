defmodule ExServiceMeshRouter.Bridge.Session do
  @moduledoc """
  High-level WS session routing API used by pipeline Route stage.
  """

  def forward(event, target) do
    ExServiceMeshRouter.Bridge.WsSupervisor.start_session(%{
      app: event.app,
      endpoint: target,
      event: event
    })

    :ok
  end
end