defmodule ExServiceMeshRouter.Protocol.Builder do
  @moduledoc """
  Builds protocol frames from internal MeshEvent structures.
  """

  alias ExServiceMeshRouter.Core.MeshEvent
  alias ExServiceMeshRouter.Protocol.Frame

  def from_event(%MeshEvent{} = event) do
    Frame.new(%{
      type: event.type,
      app: event.app,
      path: event.path,
      method: event.method,
      headers: event.headers,
      payload: event.payload,
      trace_id: event.id
    })
  end
end