defmodule Router.Shared.Plugs.TenantPipeline do
  import Plug.Conn
  alias Router.Shared.TenantResolver
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    host = 
      conn 
      |> get_req_header("host") 
      |> List.first()

    case TenantResolver.resolve(host) do
      {:ok, tenant} ->
        conn
        # 1. Always assign tenant identifier to short-lived connection metadata
        |> assign(:tenant, tenant)
        
        # 2. CRITICAL FIX FOR LIVEVIEW: Persist the tenant into the HTTP session 
        # so that the stateful on_mount token checks can read it after the websocket upgrade.
        |> put_session("tenant", tenant)
        
        # 3. Conditionally apply Ecto routing side effects safely
        |> maybe_put_ecto_tenant(tenant)
        
        # 4. Conditionally apply Ash framework process context scopes safely
        |> maybe_put_ash_tenant(tenant)

      :error ->
        Logger.warning("[Tenant Isolation Engine] Rejected request to unresolvable tenant host: #{inspect(host)}")
        
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Bad Request", message: "Missing or invalid tenant scope"}))
        |> halt() 
    end
  end

  # --- Ecto Configuration Hook ---
  defp maybe_put_ecto_tenant(conn, tenant) do
    case Application.get_env(:router_shared, :enable_ecto_tenant, false) do
      true ->
        repo = Application.get_env(:router_shared, :ecto_repo)
        if repo do
          # repo.put_tenant/1 modifies the process dictionary registry and returns an atom.
          # We execute the side effect and explicitly return the conn map.
          _ = repo.put_tenant(tenant)
          conn
        else
          Logger.error("[Tenant Isolation Engine] Configuration error: :enable_ecto_tenant is true but :ecto_repo is missing.")
          conn
        end

      false ->
        conn
    end
  end

  # --- Ash Framework Configuration Hook ---
  defp maybe_put_ash_tenant(conn, tenant) do
    case Application.get_env(:router_shared, :enable_ash_tenant, false) do
      true ->
        if Code.ensure_loaded?(Ash) do
          # We perform the state tracking assignment and return the conn chain cleanly.
          _ = Ash.set_tenant(tenant)
          conn
        else
          Logger.error("[Tenant Isolation Engine] Configuration error: :enable_ash_tenant is true but the Ash framework package is not loaded.")
          conn
        end

      false ->
        conn
    end
  end
end
