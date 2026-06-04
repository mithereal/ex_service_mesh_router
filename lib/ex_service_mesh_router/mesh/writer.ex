defmodule ExServiceMeshRouter.Mesh.Writer do
  @moduledoc """
  Writes generated manifests into each Phoenix app.
  """

  def write(app_path, manifest) do
    file = Path.join(app_path, "priv/manifest.json")

    File.mkdir_p!(Path.dirname(file))

    File.write!(
      file,
      Jason.encode!(manifest, pretty: true)
    )

    :ok
  end
end