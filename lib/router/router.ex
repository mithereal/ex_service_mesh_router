defmodule Router.Router do
  import Plug.Conn
  alias Router.Registry

  def init(opts), do: opts

  def call(conn, _) do
    host =
      conn
      |> get_req_header("host")
      |> List.first()
      |> normalize_host()

    # FIX: Extract service base host (e.g., tenant.billing.local -> billing.local)
    service_host = extract_service_host(host)

    case Registry.resolve(service_host) do
      nil ->
        send_resp(conn, 404, "unknown service: #{service_host}")

      endpoint ->
        forward(conn, endpoint)
    end
  end

  # FIX: Strips the tenant prefix to find the matching base service domain
  defp extract_service_host(nil), do: ""
  defp extract_service_host(host) do
    case String.split(host, ".") do
      [_tenant, service, tld] -> "#{service}.#{tld}"
      _ -> host
    end
  end

  defp forward(conn, endpoint) do
    # CRITICAL FIX WARNING: Calling endpoint.call/2 directly executes the child 
    # app inside the Router's process context. 
    # For full isolation, replace this direct module invocation with a proper 
    # Reverse HTTP Proxy (e.g., using `ReverseProxyPlug`) targeting the child app's internal port.
    endpoint.call(conn, endpoint.init([]))
  end

  defp normalize_host(nil), do: nil
  defp normalize_host(host), do: host |> String.split(":") |> List.first()
end
