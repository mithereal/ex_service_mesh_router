defmodule Router.Router do
  import Plug.Conn
  alias Router.Registry

  def init(opts), do: opts

  def call(conn, _opts) do
    host = 
      conn 
      |> get_req_header("host") 
      |> List.first() 
      |> normalize_host()

    service_host = extract_service_host(host)

    case Registry.resolve(service_host) do
      nil -> 
        send_resp(conn, 404, "unknown service: #{service_host}")
      endpoint -> 
        # Check if the incoming request is a WebSocket upgrade connection
        if websocket_upgrade?(conn) do
          forward_websocket(conn, endpoint)
        else
          forward_http(conn, endpoint)
        end
    end
  end

  defp extract_service_host(nil), do: ""
  defp extract_service_host(host) do
    case String.split(host, ".") do
      [_tenant, service, tld] -> "#{service}.#{tld}"
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
    # Converts base endpoints to standard http URLs if protocol is missing
    http_url = ensure_protocol(endpoint_upstream_url, "http://")
    ReverseProxyPlug.call(conn, upstream: http_url)
  end

  # Intercepts and tunnels persistent WebSocket connections 
  defp forward_websocket(conn, endpoint_upstream_url) do
    ws_url = ensure_protocol(endpoint_upstream_url, "ws://")
    
    # ReverseProxyPlugWebsocket requires options matching its runtime configuration schema
    # It converts the request and spawns a long-running proxy broker process.
    opts = ReverseProxyPlugWebsocket.init(upstream_uri: ws_url)
    ReverseProxyPlugWebsocket.call(conn, opts)
  end

  defp ensure_protocol(url, default_protocol) do
    if String.contains?(url, "://") do
      url
    else
      # Strip out loose leading forward-slashes if present in the configuration registry
      clean_url = String.trim_leading(url, "/")
      default_protocol <> clean_url
    end
  end

  defp normalize_host(nil), do: nil
  defp normalize_host(host), do: host |> String.split(":") |> List.first()
end
