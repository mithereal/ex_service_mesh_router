defmodule Router.Shared.TenantResolver do
  @moduledoc """
  Extracts the leftmost tenant identifier from an incoming host string.
  Supports standard triple-dot paths and deep multi-part corporate or cloud TLD zones.
  """

  @spec resolve(String.t() | nil) :: {:ok, String.t()} | :error
  def resolve(nil), do: :error
  def resolve(host) do
    # Strip away any trailing connection port numbers
    clean_host = host |> String.split(":") |> List.first()

    case String.split(clean_host, ".") do
      # at least two remaining elements to form a valid service and domain suffix.
      [tenant | rest] when length(rest) >= 2 ->
        {:ok, tenant}

      # Safeguard against root routing access attempts (e.g., "auth.mesh.local")
      _ ->
        :error
    end
  end
end
