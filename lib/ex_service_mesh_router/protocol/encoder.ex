defmodule ExServiceMeshRouter.Protocol.Encoder do
  @moduledoc """
  Encodes and decodes mesh protocol frames for transport layers.
  """

  alias ExServiceMeshRouter.Protocol.Frame

  # -------------------------
  # ENCODE
  # -------------------------

  def encode(%Frame{} = frame) do
    frame
    |> Map.from_struct()
    |> Jason.encode!()
  end

  # -------------------------
  # DECODE
  # -------------------------

  def decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> {:ok, struct(Frame, atomize_keys(map))}
      error -> error
    end
  end

  # -------------------------
  # HELPERS
  # -------------------------

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      {String.to_existing_atom_safe(k), v}
    end
  end
end