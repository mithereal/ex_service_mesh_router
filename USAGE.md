# Service Mesh Router — Umbrella Installation & Architecture Guide

This document sets up a Phoenix umbrella-based service mesh where:
- `apps/*` are Phoenix services
- `router` is the control plane + mesh compiler + runtime router
- manifests are generated per app inside `priv/`
- router aggregates all manifests into a global routing index

---

# 1. Create umbrella project

```bash
mix new service_mesh_umbrella --umbrella
cd service_mesh_umbrella
```

# 2. Create router application
```bash
cd apps
mix new router
```

Add dependencies

Edit:

apps/router/mix.exs

```elixir
defp deps do
  [
    {:jason, "~> 1.4"},
    {:ex_json_schema, "~> 0.10"},
    {:phoenix_pubsub, "~> 2.1"}
  ]
end
```
Then:

```bash
mix deps.get
```

# 3. Create Phoenix service apps

From umbrella root:
```bash
mix phx.new app_a --no-ecto
mix phx.new app_b --no-ecto
```
Ensure structure:

service_mesh_umbrella/
  apps/
    app_a/
    app_b/
    router/

# 4. Router mesh compiler

apps/router/lib/router/mesh/compiler.ex
```elixir
defmodule Router.Mesh.Compiler do
  alias Router.Mesh.Scanner
  alias Router.Mesh.Introspector
  alias Router.Mesh.Writer

  def compile do
    apps = Scanner.scan_umbrella_apps()

    Enum.each(apps, fn app ->
      manifest = Introspector.build(app)
      Writer.write(app.path, manifest)
    end)

    :ok
  end
end
```

# 5. Umbrella app scanner

apps/router/lib/router/mesh/scanner.ex

```elixir
defmodule Router.Mesh.Scanner do
  def scan_umbrella_apps do
    root = Path.expand("../../..", __DIR__)
    apps_path = Path.join(root, "apps")

    apps_path
    |> File.ls!()
    |> Enum.map(fn app ->
      %{app: String.to_atom(app), path: Path.join(apps_path, app)}
    end)
    |> Enum.reject(fn app -> app.app == :router end)
  end
end
```

# 6. Manifest output per app

Each app writes:

apps/app_a/priv/manifest.json
apps/app_b/priv/manifest.json

Example manifest:

```json
{
  "app": "app_a",
  "version": 1,
  "domains": ["localhost"],
  "http": {
    "/api/users": ["GET", "POST"],
    "/api/health": ["GET"]
  },
  "ws": {
    "topics": ["room:*", "user:*"]
  }
} 
```

# 7. Router runtime startup

apps/router/lib/router/application.ex

```elixir
def start(_type, _args) do
  children = [
    Router.Discovery.AutoRegistry,
    Router.Routing.AppRouter
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

# 8. Run mesh compiler

From umbrella root:

```bash
mix cmd --app router mix run -e "Router.Mesh.Compiler.compile()"
```
OR:
```bash
mix run --no-halt
```

# 9. Routing model
HTTP flow

client → router → manifest lookup → forward to Phoenix app

WebSocket flow

client → router → topic_router → app session

# 10. Global routing index

Generated file:

router/priv/cache/manifests.json

Contains:

all apps
all HTTP routes
all WebSocket topics
reverse routing index

# 11. Run tests

```elixir
mix test
```

#12. Key commands

Compile manifests:

```bash
mix cmd --app router mix mesh.compile
```

Run router:

```bash
mix run --no-halt
```

Run tests:

```bash
mix test
```

### SYSTEM MODEL
apps = Phoenix services
router = control plane + compiler + runtime router
manifests = source of truth contracts
umbrella = filesystem orchestration layer

### RESULT

You now have:

Phoenix umbrella service mesh
compile-time app discovery
manifest-driven routing system
centralized router control plane
scalable multi-app architecture