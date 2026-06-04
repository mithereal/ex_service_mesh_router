defmodule Shared.Tooling.DiffTool do
  @moduledoc """
  Generic deep diff tool for manifests and routing structures.
  """

  def diff(a, b) when is_map(a) and is_map(b) do
    %{
      changed: a != b,
      added: map_diff(a, b),
      removed: map_diff(b, a)
    }
  end

  defp map_diff(a, b) do
    a
    |> Enum.reject(fn {k, v} ->
      Map.get(b, k) == v
    end)
    |> Enum.into(%{})
  end

  def equal?(a, b), do: a == b
end