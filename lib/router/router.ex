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

    case Registry.resolve(host) do
      nil ->
        send_resp(conn, 404, "unknown service: #{host}")

      endpoint ->
        forward(conn, endpoint)
    end
  end

  defp forward(conn, endpoint) do
    endpoint.call(conn, endpoint.init([]))
  end

  defp normalize_host(nil), do: nil
  defp normalize_host(host), do: host |> String.split(":") |> List.first()
end
