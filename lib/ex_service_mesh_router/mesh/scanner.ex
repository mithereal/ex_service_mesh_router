defmodule ExServiceMeshRouter.Mesh.Scanner do
  @moduledoc """
  Discovers Phoenix apps under apps/*.
  """

  def scan do
    "apps/*"
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(&normalize_app/1)
  end

  defp normalize_app(path) do
    app =
      path
      |> Path.basename()
      |> String.to_atom()

    %{app: app, path: path}
  end
end