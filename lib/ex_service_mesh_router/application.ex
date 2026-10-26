defmodule ExServiceMeshRouter.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("GATEWAY_PORT") || "4000")

    children = [
      # 1. Start the upgraded hybrid cluster state registry
      {Router.Registry, name: Router.Registry},

      # 2. Bind the modern Bandit web server layer to proxy incoming dual-protocol traffic
      {Bandit,
       plug: Router.Router,
       port: port}
    ]

    # One_For_One strategy ensures that if Bandit triggers an internal connection crash,
    # it does not teardown or clear the memory tables held inside our active Registry process.
    opts = [strategy: :one_for_one, name: ExServiceMeshRouter.Supervisor]
    Logger.info("[ExServiceMeshRouter] Starting pure-Elixir Bandit edge gateway on port #{port}...")
    Supervisor.start_link(children, opts)
  end
end
