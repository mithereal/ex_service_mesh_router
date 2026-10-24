defmodule Router.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Asynchronous mesh service discovery engine
      Router.Registry,

      # 2. Start the HTTP/WebSocket Gateway listener using Bandit
      {Bandit,
       plug: Router.Router, # Forwards requests to your dual-protocol edge router
       port: String.to_integer(System.get_env("GATEWAY_PORT") || "4000")}
    ]

    opts = [strategy: :one_for_one, name: Router.Supervisor]
    Logger.info("[ExServiceMeshRouter] Starting pure-Elixir Bandit edge gateway on port 4000...")
    Supervisor.start_link(children, opts)
  end
end
