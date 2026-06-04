defmodule ExServiceMeshRouter.Protocol.Frame do
  @moduledoc """
  Canonical wire format for all mesh communication.

  Used across:
  - HTTP → EventBus
  - WS → Bridge
  - Pipeline stages
  - Inter-service communication
  """

  @enforce_keys [:type, :app, :payload]
  defstruct [
    :type,        # :http | :ws | :control | :manifest
    :app,
    :path,
    :method,
    :headers,
    :payload,
    :trace_id,
    :timestamp
  ]

  def new(attrs) do
    %__MODULE__{
      type: attrs.type,
      app: attrs.app,
      path: attrs[:path],
      method: attrs[:method],
      headers: attrs[:headers] || %{},
      payload: attrs.payload,
      trace_id: attrs[:trace_id] || generate_trace_id(),
      timestamp: System.system_time(:millisecond)
    }
  end

  defp generate_trace_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end