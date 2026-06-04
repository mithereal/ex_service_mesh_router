defmodule ExServiceMeshRouter.Mesh.ManifestBuilder do
  @moduledoc """
  Normalizes extracted app data into canonical mesh manifest.
  """

  def build(raw) do
    %{
      app: raw.app,
      version: 1,
      http: normalize_http(raw.http),
      ws: normalize_ws(raw.ws),
      domains: raw.domains
    }
  end

  defp normalize_http(http), do: http

  defp normalize_ws(ws) do
    %{
      topics: Map.get(ws, :topics, [])
    }
  end
end