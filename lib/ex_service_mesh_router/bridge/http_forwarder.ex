defmodule ExServiceMeshRouter.Bridge.HttpForwarder do
  @moduledoc """
  Forwards HTTP requests to resolved Phoenix apps.
  """

  def forward(event, target) do
    url = build_url(target, event.path)

    headers = normalize_headers(event.headers)

    body = event.payload || ""

    case HTTPoison.request(event.method, url, body, headers, recv_timeout: 5_000) do
      {:ok, %{status_code: code, body: resp_body}} ->
        {:ok, %{status: code, body: resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_url(%{host: host, port: port}, path) do
    "http://#{host}:#{port}#{path}"
  end

  defp normalize_headers(headers) when is_map(headers) do
    Enum.into(headers, [])
  end

  defp normalize_headers(headers) when is_list(headers), do: headers
end