defmodule ExServiceMeshRouter.Application do
  @moduledoc """
  Entry point for the service mesh router.

  Responsibilities:
  - Starts discovery layer (AutoRegistry)
  - Starts manifest state + sync loop
  - Starts pipeline registry (dynamic routing engine)
  - Starts bridge supervision (WS forwarding layer)
  - Starts Bandit HTTP ingress
  """

  use Application

  def start(_type, _args) do
    port = http_port()

    children = [
      # Core discovery of Phoenix apps
      ExServiceMeshRouter.Discovery.AutoRegistry,

      # Runtime manifest state (authoritative routing knowledge)
      ExServiceMeshRouter.Discovery.ManifestStore,

      # Dynamic routing pipeline registry
      ExServiceMeshRouter.Pipeline.Registry,

      # Continuous manifest synchronization loop
      ExServiceMeshRouter.Discovery.ManifestSync,

      # WebSocket bridge supervisor (Phoenix <-> Mesh)
      ExServiceMeshRouter.Bridge.Supervisor,

      # HTTP + WS ingress (Bandit)
      {Bandit,
        plug: ExServiceMeshRouter.Router,
        scheme: :http,
        port: port}
    ]

    opts = [
      strategy: :one_for_one,
      name: ExServiceMeshRouter.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  defp http_port do
    Application.get_env(:ex_service_mesh_router, :http, [])
    |> Keyword.get(:port, 8080)
  end
end