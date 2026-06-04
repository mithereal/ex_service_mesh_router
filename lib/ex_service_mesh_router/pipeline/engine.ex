defmodule ExServiceMeshRouter.Pipeline.Engine do
  @moduledoc """
  Executes a named pipeline by running registered stages sequentially.
  """

  def run(event, pipeline_name) do
    stages =
      ExServiceMeshRouter.Pipeline.Registry.get(pipeline_name)

    ctx =
      ExServiceMeshRouter.Core.PipelineContext.new(event)

    Enum.reduce_while(stages, ctx, fn stage, ctx ->
      ctx = stage.call(ctx)

      if ctx.halted do
        {:halt, ctx}
      else
        {:cont, ctx}
      end
    end)
  end
end