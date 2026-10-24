defmodule ExServiceMeshRouter.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Fetch the gateway port dynamically from environment or default config keys
    port = String.to_integer(System.get_env("GATEWAY_PORT") || "4000")

    children = [
      Router.Registry,

      # 2. Bind the modern Bandit web server layer to proxy incoming dual-protocol traffic
      {Bandit,
       plug: Router.Router,
       port: port}
    ]

    opts = [strategy: :one_for_one, name: ExServiceMeshRouter.Supervisor]
    Logger.info("[ExServiceMeshRouter] Starting pure-Elixir Bandit edge gateway on port #{port}...")
    Supervisor.start_link(children, opts)
  end
end
