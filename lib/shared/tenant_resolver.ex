defmodule Router.Shared.TenantResolver do
  @moduledoc """
  Extracts the tenant identifier from the incoming request host string.
  Expects format: tenant.service.tld (e.g., "acme.auth.mesh.local")
  """

  @spec resolve(String.t() | nil) :: {:ok, String.t()} | :error
  def resolve(nil), do: :error
  def resolve(host) do
    # Remove any trailing port number if present (e.g., "acme.auth.mesh.local:4000")
    clean_host = host |> String.split(":") |> List.first()

    case String.split(clean_host, ".") do
      [tenant, _service, _tld] ->
        {:ok, tenant}

      # Fallback for handling multi-part TLDs or root service addresses
      _ ->
        :error
    end
  end
end
