defmodule ExServiceMeshRouter.Utils.Id do
  @moduledoc """
  ID utilities for tracing, events, and protocol frames.
  """

  @doc """
  Generates a short trace id.
  """
  def trace_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @doc """
  Generates a longer unique id for internal objects.
  """
  def uuid_like do
    Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end
end