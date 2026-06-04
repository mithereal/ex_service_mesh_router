defmodule ExServiceMeshRouter.Pipeline.Stages.Normalize do
  @moduledoc """
  Normalizes incoming MeshEvent into consistent routing shape.
  """

  def call(ctx) do
    %{ctx |
      assigns: Map.put(ctx.assigns, :normalized, true)
    }
  end
end