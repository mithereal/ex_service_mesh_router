# config/test.exs

# Configure downstream application reflections for the lifecycle worker
config :router_shared,
  app_name: :auth_app,
  # Forces the lifecycle worker to run in Mode A (Local Validation) 
  # to prevent hitting missing external Erlang nodes during tests.
  gateway_node: Node.self(),

  # Multi-framework testing flags
  enable_ecto_tenant: true,
  # Mock repository pointer for testing
  ecto_repo: Router.Integration.MockRepo,
  enable_ash_tenant: false

# Configure the mock app endpoint settings matching the lifecycle test profile
config :auth_app, :endpoint, Router.Integration.MockEndpoint

config :auth_app, Router.Integration.MockEndpoint,
  url: [host: "test-service.mesh.local"],
  http: [port: 4998]
