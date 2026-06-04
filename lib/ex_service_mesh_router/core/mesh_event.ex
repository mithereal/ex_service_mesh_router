defmodule ExServiceMeshRouter.Core.MeshEvent do
  @moduledoc """
  Unified event model for HTTP and WebSocket traffic.
  """

  defstruct [
    :id,
    :type,       # :http | :ws
    :app,
    :path,
    :method,
    :headers,
    :payload,
    :conn_ref
  ]

  def new(attrs) do
    %__MODULE__{
      id: Base.encode16(:crypto.strong_rand_bytes(8)),
      type: attrs.type,
      app: attrs.app,
      path: attrs[:path],
      method: attrs[:method],
      headers: attrs[:headers] || %{},
      payload: attrs[:payload],
      conn_ref: attrs[:conn_ref]
    }
  end
end