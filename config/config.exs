import Config

config :ex_service_mesh_router, Router.Router,
  http_port: String.to_integer(System.get_env("GATEWAY_PORT") || "4000")
