defmodule ExServiceMeshRouter.Utils.Map do
  @moduledoc """
  Map utilities used for manifests, headers, and protocol normalization.
  """

  @doc """
  Deep merge two maps (used for manifest overlays).
  """
  def deep_merge(a, b) do
    Map.merge(a, b, fn
      _k, v1, v2 when is_map(v1) and is_map(v2) ->
        deep_merge(v1, v2)

      _k, _v1, v2 ->
        v2
    end)
  end

  @doc """
  Converts keyword list headers to map.
  """
  def normalize_headers(headers) when is_list(headers),
      do: Enum.into(headers, %{})

  def normalize_headers(headers) when is_map(headers),
      do: headers
end