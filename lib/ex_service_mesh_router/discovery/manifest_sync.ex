defmodule ExServiceMeshRouter.Discovery.ManifestSync do
  @moduledoc """
  Periodically synchronizes routing manifests from all discovered Phoenix apps.

  Responsibilities:
  - Discover apps via AutoRegistry
  - Fetch /mesh/manifest from each app
  - Version and store manifests
  - Provide input for diff + rollback systems
  """

  use GenServer

  alias ExServiceMeshRouter.Discovery.{
    AutoRegistry,
    ManifestStore
    }

  @default_interval 10_000

  # -------------------------
  # STARTUP
  # -------------------------

  def start_link(_),
      do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    interval = sync_interval()

    schedule(interval)

    {:ok, Map.put(state, :interval, interval)}
  end

  # -------------------------
  # LOOP
  # -------------------------

  def handle_info(:sync, state) do
    AutoRegistry.list_apps()
    |> Enum.each(&sync_app/1)

    schedule(state.interval)

    {:noreply, state}
  end

  # -------------------------
  # CORE SYNC LOGIC
  # -------------------------

  defp sync_app(app) do
    case AutoRegistry.lookup(app) do
      {:ok, endpoint} ->
        fetch_manifest(app, endpoint)

      _ ->
        :ignore
    end
  end

  defp fetch_manifest(app, endpoint) do
    case http_get_manifest(endpoint) do
      {:ok, manifest} ->
        store_manifest(app, manifest)

      {:error, reason} ->
        handle_fetch_error(app, reason)
    end
  end

  defp http_get_manifest(endpoint) do
    url = build_url(endpoint, "/mesh/manifest")

    case HTTPoison.get(url, [], recv_timeout: 2_000) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: code}} ->
        {:error, {:bad_status, code}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_manifest(app, manifest) do
    case ManifestStore.update(app, manifest) do
      {:ok, version} ->
        {:ok, %{app: app, version: version}}

      other ->
        other
    end
  end

  defp handle_fetch_error(app, reason) do
    # future hook:
    # - mark node unhealthy
    # - trigger partial rollback
    # - emit telemetry
    {:error, {app, reason}}
  end

  # -------------------------
  # SCHEDULER
  # -------------------------

  defp schedule(interval) do
    Process.send_after(self(), :sync, interval)
  end

  # -------------------------
  # CONFIG
  # -------------------------

  defp sync_interval do
    Application.get_env(:ex_service_mesh_router, :discovery, [])
    |> Keyword.get(:sync_interval_ms, @default_interval)
  end

  defp build_url(endpoint, path) do
    "http://#{endpoint.host}:#{endpoint.port}#{path}"
  end
end