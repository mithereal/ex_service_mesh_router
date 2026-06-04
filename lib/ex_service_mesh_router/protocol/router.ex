defmodule ExServiceMeshRouter.Protocol.Router do
  @moduledoc """
  Protocol-level routing abstraction.

  Converts Frames into pipeline events or bridge messages.
  """

  alias ExServiceMeshRouter.Core.EventBus
  alias ExServiceMeshRouter.Protocol.Frame

  def route(%Frame{} = frame) do
    case frame.type do
      :http ->
        EventBus.emit(frame)

      :ws ->
        EventBus.emit(frame)

      :manifest ->
        handle_manifest(frame)

      :control ->
        handle_control(frame)
    end
  end

  defp handle_manifest(frame) do
    # future: push into ManifestStore directly
    :ok
  end

  defp handle_control(frame) do
    # future: cluster coordination, rollback triggers, etc.
    :ok
  end
end