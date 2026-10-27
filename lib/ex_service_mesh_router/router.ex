defmodule Router.Router do
  import Plug.Conn
  alias Router.Registry
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # 1. Identity Phase: Attempt extraction across public browser hosts or backplane headers
    service_host = determine_routing_target(conn)

    case Registry.resolve(service_host) do
      nil ->
        Logger.warning(
          "[Backplane Error] Unable to resolve route target for path key: #{inspect(service_host)}"
        )

        send_resp(conn, 404, "unknown service: #{service_host}")

      endpoint ->
        # 2. Proxy Execution Phase: Check protocol type and pipe the network stream
        if websocket_upgrade?(conn) do
          forward_websocket(conn, endpoint)
        else
          forward_http(conn, endpoint)
        end
    end
  end

  # --- Routing Context Discovery Pipeline ---
  defp determine_routing_target(conn) do
    # Attempt to read standard edge browser host header
    host_header =
      conn
      |> get_req_header("host")
      |> List.first()
      |> normalize_host()

    # Attempt to read direct microservice-to-microservice backplane mesh overrides
    backplane_header =
      conn
      |> get_req_header("x-backplane-service")
      |> List.first()

    # Resolution prioritization chain
    cond do
      # If microservice explicitly passed an internal mesh token, prioritize it
      backplane_header && backplane_header != "" ->
        backplane_header

      # If edge request carries standard multi-tenant subdomain maps
      host_header && host_header != "" ->
        extract_service_host(host_header)

      # Ultimate fallback: check query strings if headers were fully stripped by a proxy layer
      true ->
        conn = fetch_query_params(conn)
        Map.get(conn.query_params, "backplane_service", "")
    end
  end

  defp extract_service_host(nil), do: ""

  defp extract_service_host(host) do
    case String.split(host, ".") do
      # Maps tenant1.auth.mesh.local -> auth.mesh.local
      [_tenant, service, tld] -> "#{service}.#{tld}"
      # Support deep structures like tenant1.auth.mesh.internal.zone -> auth.mesh.internal.zone
      [tenant | rest] when length(rest) >= 2 -> Enum.join(rest, ".")
      # Fallback for flat development calls (e.g. "localhost")
      _ -> host
    end
  end

  # Helper to identify WebSocket handshake requests
  defp websocket_upgrade?(conn) do
    upgrade_header =
      conn
      |> get_req_header("upgrade")
      |> List.first()

    case upgrade_header do
      nil -> false
      header -> String.downcase(header) == "websocket"
    end
  end

  # Handles normal stateful HTTP forwarding paths
  defp forward_http(conn, endpoint_upstream_url) do
    http_url = ensure_protocol(endpoint_upstream_url, "http://")
    ReverseProxyPlug.call(conn, upstream: http_url)
  end

  # Intercepts and tunnels persistent WebSocket connections 
  defp forward_websocket(conn, endpoint_upstream_url) do
    ws_url = ensure_protocol(endpoint_upstream_url, "ws://")
    opts = ReverseProxyPlugWebsocket.init(upstream_uri: ws_url)
    ReverseProxyPlugWebsocket.call(conn, opts)
  end

  defp ensure_protocol(url, default_protocol) do
    if String.contains?(url, "://") do
      url
    else
      clean_url = String.trim_leading(url, "/")
      default_protocol <> clean_url
    end
  end

  defp normalize_host(nil), do: nil
  defp normalize_host(host), do: host |> String.split(":") |> List.first()
end
