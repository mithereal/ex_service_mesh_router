defmodule Router.Application do
  use Application

  def start(_type, _args) do
    children = [
      Router.Registry
    ]

    opts = [strategy: :one_for_one, name: Router.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
