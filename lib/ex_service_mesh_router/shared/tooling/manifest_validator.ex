defmodule Shared.Tooling.ManifestValidator do
  @moduledoc """
  Validates generated mesh manifests against schema rules.
  """

  @schema_file Path.expand("../mesh_contracts/manifest_schema.json", __DIR__)

  def validate(manifest) when is_map(manifest) do
    schema = load_schema()

    case ExJsonSchema.Validator.validate(schema, manifest) do
      :ok -> :ok
      {:error, errors} -> {:error, errors}
    end
  end

  def validate(_), do: {:error, :invalid_manifest_type}

  defp load_schema do
    @schema_file
    |> File.read!()
    |> Jason.decode!()
    |> ExJsonSchema.Schema.resolve()
  end
end