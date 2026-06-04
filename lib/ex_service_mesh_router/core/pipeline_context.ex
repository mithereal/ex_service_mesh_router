defmodule ExServiceMeshRouter.Core.PipelineContext do
  @moduledoc """
  Mutable execution context passed through pipeline stages.
  """

  defstruct [
    :event,
    :halted,
    assigns: %{}
  ]

  def new(event),
      do: %__MODULE__{event: event, halted: false}
end