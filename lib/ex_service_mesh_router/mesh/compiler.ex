defmodule ExServiceMeshRouter.Mesh.Compiler do
  @moduledoc """
  Orchestrates full mesh compilation pipeline.
  """

  alias ExServiceMeshRouter.Mesh.{Scanner, Introspector, ManifestBuilder, Writer}

  def compile do
    Scanner.scan()
    |> Enum.each(&compile_app/1)

    :ok
  end

  def compile_app(%{app: app, path: path}) do
    raw = Introspector.extract(%{app: app, path: path})
    manifest = ManifestBuilder.build(raw)

    Writer.write(path, manifest)

    {:ok, app}
  end
end