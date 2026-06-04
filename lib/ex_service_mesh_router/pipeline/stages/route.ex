defmodule ExServiceMeshRouter.Pipeline.Stages.Route do
  @moduledoc """
  Final execution stage: forwards HTTP or WS traffic.
  """

  def call(ctx) do
    event = ctx.event
    target = ctx.assigns.target

    case event.type do
      :http ->
        ExServiceMeshRouter.Http.Forwarder.forward(event, target)

      :ws ->
        ExServiceMeshRouter.Bridge.Session.forward(event, target)
    end

    %{ctx | halted: true}
  end
end