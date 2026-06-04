import Config

port =
  System.get_env("MESH_ROUTER_PORT", "8080")
  |> String.to_integer()

sync_interval =
  System.get_env("MESH_SYNC_INTERVAL", "10000")
  |> String.to_integer()

config :ex_service_mesh_router,
       http: [
         port: port
       ],
       discovery: [
         sync_interval_ms: sync_interval
       ]

# Optional: external registry seed
config :ex_service_mesh_router,
       seed_apps:
         System.get_env("MESH_SEED_APPS", "")
         |> String.split(",", trim: true)