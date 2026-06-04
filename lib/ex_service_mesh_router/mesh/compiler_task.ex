defmodule Mix.Tasks.Mesh.Compile do
  use Mix.Task

  @moduledoc """
  Runs full mesh compilation.
  """

  alias ExServiceMeshRouter.Mesh.Compiler

  def run(_args) do
    Mix.shell().info("Compiling service mesh manifests...")

    Compiler.compile()

    Mix.shell().info("Mesh compilation complete.")
  end
end