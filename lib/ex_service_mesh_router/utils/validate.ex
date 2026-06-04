defmodule ExServiceMeshRouter.Utils.Validate do
  @moduledoc """
  Lightweight validation helpers for runtime safety checks.
  """

  @doc """
  Ensures value is not nil.
  """
  def present?(nil), do: false
  def present?(""), do: false
  def present?(_), do: true

  @doc """
  Ensures list is not empty.
  """
  def non_empty_list?([]), do: false
  def non_empty_list?(_), do: true

  @doc """
  Safe atom conversion (restricted to existing atoms only).
  """
  def to_existing_atom(str) when is_binary(str) do
    String.to_existing_atom(str)
  rescue
    _ -> :invalid_atom
  end
end