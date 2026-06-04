defmodule Shared.Tooling.SchemaUtils do
  @moduledoc """
  Helpers for working with mesh schemas.
  """

  def load_json(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  def normalize_manifest(manifest) do
    %{
      app: manifest["app"],
      version: manifest["version"] || 1,
      http: manifest["http"] || %{},
      ws: normalize_ws(manifest["ws"])
    }
  end

  defp normalize_ws(nil), do: %{topics: []}
  defp normalize_ws(ws), do: %{topics: Map.get(ws, "topics", [])}
end