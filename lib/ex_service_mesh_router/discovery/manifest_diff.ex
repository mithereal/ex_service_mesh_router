defmodule ExServiceMeshRouter.Discovery.ManifestDiff do
  @moduledoc """
  Computes a structured diff between two routing manifests.

  Used by:
  - ManifestSync (change detection)
  - ManifestRollback (reverse patching)
  - ManifestPatcher (routing mutation engine)

  Diff output is intentionally patch-oriented, not just comparison-oriented.
  """

  @doc """
  Returns a diff map describing routing changes between manifests.
  """
  def diff(old, new) do
    %{
      http: diff_http(old, new),
      ws: diff_ws(old, new),
      domains: diff_domains(old, new)
    }
  end

  # -------------------------
  # HTTP ROUTE DIFFING
  # -------------------------

  defp diff_http(old, new) do
    old_routes = normalize_http(old)
    new_routes = normalize_http(new)

    %{
      added: map_keys(new_routes) -- map_keys(old_routes),
      removed: map_keys(old_routes) -- map_keys(new_routes),
      changed: changed_http_routes(old_routes, new_routes)
    }
  end

  defp changed_http_routes(old_routes, new_routes) do
    common_keys =
      Map.keys(old_routes)
      |> Enum.filter(&Map.has_key?(new_routes, &1))

    Enum.reduce(common_keys, [], fn path, acc ->
      if old_routes[path] != new_routes[path] do
        [{path, %{from: old_routes[path], to: new_routes[path]}} | acc]
      else
        acc
      end
    end)
  end

  # -------------------------
  # WS TOPIC DIFFING
  # -------------------------

  defp diff_ws(old, new) do
    old_topics = normalize_ws(old)
    new_topics = normalize_ws(new)

    %{
      added: new_topics -- old_topics,
      removed: old_topics -- new_topics
    }
  end

  # -------------------------
  # DOMAIN DIFFING
  # -------------------------

  defp diff_domains(old, new) do
    old_domains = Map.get(old || %{}, :domains, [])
    new_domains = Map.get(new || %{}, :domains, [])

    %{
      added: new_domains -- old_domains,
      removed: old_domains -- new_domains
    }
  end

  # -------------------------
  # NORMALIZATION HELPERS
  # -------------------------

  defp normalize_http(%{http: http}) when is_map(http), do: http
  defp normalize_http(_), do: %{}

  defp normalize_ws(%{ws: %{topics: topics}}) when is_list(topics), do: topics
  defp normalize_ws(_), do: []

  defp map_keys(map) when is_map(map), do: Map.keys(map)
  defp map_keys(_), do: []
end