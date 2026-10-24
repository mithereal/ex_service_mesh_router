defmodule Router.Shared.Hooks.TenantLiveMount do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    # Read the tenant from your session (assigned during initial HTTP pipeline pass)
    tenant = session["tenant"]

    # Re-apply the process environment context for the LiveView's isolated stateful process loop
    if Application.get_env(:router_shared, :enable_ecto_tenant, false), do: App.Repo.put_tenant(tenant)
    if Application.get_env(:router_shared, :enable_ash_tenant, false) and Code.ensure_loaded?(Ash), do: Ash.set_tenant(tenant)

    {:cont, assign(socket, :tenant, tenant)}
  end
end
