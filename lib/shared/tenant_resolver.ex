defmodule Router.Shared.TenantResolver do
  @moduledoc """
  Extracts tenant from request host inside Phoenix apps.
  """

  def resolve(host) do
    case String.split(host, ".") do
      [tenant, _service, _tld] ->
        {:ok, tenant}

      _ ->
        :error
    end
  end
end
