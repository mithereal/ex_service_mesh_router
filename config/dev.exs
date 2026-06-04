import Config

config :ex_service_mesh_router,
       http: [
         port: 8080
       ],
       discovery: [
         sync_interval_ms: 5_000
       ]

config :logger,
       level: :debug