defmodule Router.Shared.Plugs.TenantPipeline do
  import Plug.Conn
  alias Router.Shared.TenantResolver

  def init(opts), do: opts

  def call(conn, _opts) do
    host = 
      conn 
      |> get_req_header("host") 
      |> List.first()
      |> case do
        nil -> ""
        val -> val |> String.split(":") |> List.first()
      end

    case TenantResolver.resolve(host) do
      {:ok, tenant} ->
        conn
        |> assign(:tenant, tenant)
        # |> put_ecto_tenant(tenant) # Un-comment if using Ecto.Repo.put_tenant/1

      :error ->
        conn
        |> send_resp(400, "Missing or invalid tenant scope")
        |> halt()
    end
  end
end
