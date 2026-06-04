defmodule ExServiceMeshRouter.Router do
  @moduledoc """
  Bandit ingress router.

  Responsibilities:
  - Match incoming HTTP requests
  - Detect /apps/* routes
  - Delegate all logic to AppRouter
  - Remain stateless (no routing logic here)
  """

  use Plug.Router

  plug :match
  plug :dispatch

  @doc """
  Entry point for all mesh-routed traffic.

  Example:
    /apps/app_a/api/users
    /apps/app_b/socket/websocket
  """

  match "/apps/*_path" do
    ExServiceMeshRouter.Routing.AppRouter.route(conn)
  end

  @doc """
  Health check endpoint for Bandit / load balancers.
  """

  get "/health" do
    send_resp(conn, 200, "ok")
  end

  @doc """
  Fallback route for non-mesh traffic.
  """

  match _ do
    send_resp(conn, 404, "not found")
  end
end