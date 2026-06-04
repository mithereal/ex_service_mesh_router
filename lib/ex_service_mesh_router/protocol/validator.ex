defmodule ExServiceMeshRouter.Protocol.Validator do
  @moduledoc """
  Validates protocol frames before entering pipeline.
  """

  alias ExServiceMeshRouter.Protocol.Frame

  def validate(%Frame{} = frame) do
    cond do
      is_nil(frame.app) ->
        {:error, :missing_app}

      frame.type not in [:http, :ws, :control, :manifest] ->
        {:error, :invalid_type}

      true ->
        :ok
    end
  end
end