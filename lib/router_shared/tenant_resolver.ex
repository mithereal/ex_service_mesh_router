defmodule Router.Shared.TenantResolver do
  @moduledoc """
  Extracts the leftmost tenant identifier from an incoming host string.
  Supports standard triple-dot paths and deep multi-part corporate or cloud TLD zones.
  Includes advanced regular expression and wildcard safeguarding parameters to intercept root routing leaks.
  """

  @spec resolve(String.t() | nil) :: {:ok, String.t()} | :error
  def resolve(nil), do: :error
  def resolve(host) do
    # Strip away any trailing connection port numbers
    clean_host = host |> String.split(":") |> List.first()

    # Apply configuration safeguards prior to performing domain extraction splits
    if safeguarded?(clean_host) do
      :error
    else
      case String.split(clean_host, ".") do
        # At least two remaining elements to form a valid service and domain suffix.
        [tenant | rest] when length(rest) >= 2 ->
          # Final validation step: ensure the extracted tenant token itself isn't a restricted pattern
          validate_tenant_token(tenant)

        # Safeguard against root routing access attempts (e.g., "auth.mesh.local")
        _ ->
          :error
      end
    end
  end

  # --- Internal Safeguarding Engine Functions ---

  defp safeguarded?(clean_host) do
    # Dynamically fetch optional full host wildcard or regex pattern matchers
    # Example format: [~r/^management\..*/, ~r/.*\.internal\.zone$/]
    ignored_patterns = Application.get_env(:router_shared, :ignored_host_patterns, [])
    
    Enum.any?(ignored_patterns, fn pattern -> 
      String.match?(clean_host, pattern)
    end)
  end

  defp validate_tenant_token(tenant) do
    # Dynamically fetch restricted tenant token patterns
    # Example format: [~r/^admin$/, ~r/^internal-.*$/, ~r/.*-dev$/]
    restricted_patterns = Application.get_env(:router_shared, :restricted_tenant_patterns, [])

    if Enum.any?(restricted_patterns, fn pattern -> String.match?(tenant, pattern) end) do
      :error
    else
      {:ok, tenant}
    end
  end
end
