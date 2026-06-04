defmodule ExServiceMeshRouter.Pipeline.Stages.ResolveApp do
  @moduledoc """
  Resolves Phoenix app from registry and attaches routing target.
  """

  def call(ctx) do
    target =
      ExServiceMeshRouter.Discovery.AutoRegistry.lookup(ctx.event.app)

    %{ctx |
      assigns: Map.put(ctx.assigns, :target, target)
    }
  end
end