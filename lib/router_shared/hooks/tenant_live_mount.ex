defmodule Router.Shared.Hooks.TenantLiveMount do
  import Phoenix.Component
  import Phoenix.LiveView
  require Logger

  def on_mount(:default, _params, session, socket) do
    # 1. Read the tenant from your session (assigned during initial HTTP pipeline pass)
    case Map.get(session, "tenant") do
      nil ->
        Logger.warning("[Tenant LiveView Mount Guard] Attempted connection to unscoped session context. Halting mount.")
        # Gracefully halt the stateful process and send the user to an un-isolated landing safe zone
        {:halt, redirect(socket, to: "/error-invalid-tenant")}

      tenant ->
        # 2. Re-apply process dictionary side-effects for this long-lived LiveView process loops safely
        _ = maybe_put_ecto_tenant(tenant)
        _ = maybe_put_ash_tenant(tenant)

        # 3. Securely update the socket state mapping assigns
        {:cont, assign(socket, :tenant, tenant)}
    end
  end

  # --- Multi-Framework Isolation Guard Engines ---

  defp maybe_put_ecto_tenant(tenant) do
    case Application.get_env(:router_shared, :enable_ecto_tenant, false) do
      true ->
        # FIX: Dynamically fetch the calling application's explicit repo pointer
        repo = Application.get_env(:router_shared, :ecto_repo)
        
        if repo do
          repo.put_tenant(tenant)
        else
          Logger.error("[Tenant LiveView Mount Guard] Config error: :enable_ecto_tenant is true but :ecto_repo is missing.")
        end

      false ->
        :ok
    end
  end

  defp maybe_put_ash_tenant(tenant) do
    case Application.get_env(:router_shared, :enable_ash_tenant, false) do
      true ->
        if Code.ensure_loaded?(Ash) do
          Ash.set_tenant(tenant)
        else
          Logger.error("[Tenant LiveView Mount Guard] Config error: :enable_ash_tenant is true but Ash framework package is not loaded.")
        end

      false ->
        :ok
    end
  end
end
