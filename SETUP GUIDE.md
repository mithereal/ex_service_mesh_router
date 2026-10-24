# Setup Guide: ExServiceMeshRouter in Phoenix Umbrellas

This guide outlines how to install and configure `ex_service_mesh_router` as a BEAM-native edge gateway and internal backplane within an Elixir Umbrella project running Bandit.

---

## 1. Directory Structure

Set up your umbrella project with isolated applications for the gateway router (`ex_service_mesh_router`), shared multi-tenancy code (`router_shared`), and your business microservices.

---

## 2. Shared Core Installation (`apps/router_shared`)

The `router_shared` package isolates multi-tenant parsing logic so backend apps can consume it uniformly. 

* Configure dependencies in `apps/router_shared/mix.exs` to include `:plug`, `:jason`, and optionally `:ecto_sql` and `:ash`.
* Implement the tenant resolver in `apps/router_shared/lib/tenant_resolver.ex` to extract tenant identifiers from incoming host strings formatted as `tenant.service.tld`.
* Create the tenant pipeline plug in `apps/router_shared/lib/plugs/tenant_pipeline.ex` to assign tenant metadata, update sessions, and apply Ecto or Ash tenancy scopes conditionally.

---

## 3. Gateway Installation (`apps/ex_service_mesh_router`)

The gateway application functions as a lightweight, dual-protocol reverse proxy handling service routing.

* Define project dependencies in `apps/ex_service_mesh_router/mix.exs` including `:reverse_proxy_plug`, `:reverse_proxy_plug_websocket`, `:gun`, `:req`, and `:bandit`.
* Build the service discovery registry (`Router.Registry`) using a `GenServer` to map loaded application endpoints and hosts dynamically.
* Implement the edge router (`Router.Router`) to resolve routes and forward HTTP or WebSocket traffic via `ReverseProxyPlug` and `ReverseProxyPlugWebsocket`.
* Initialize the supervision tree in `ExServiceMeshRouter.Application` to run the registry and the Bandit edge gateway.

---

## 4. Downstream Application Setup (e.g., `apps/auth_app`)

Configure downstream microservices to integrate with the shared pipeline and announce their endpoints.

* Add `router_shared` as an umbrella dependency in your downstream `mix.exs` files.
* Update application environments in `config/config.exs` with endpoint modules, service host routing keys, and optional Ecto/Ash multi-tenancy parameters.
* Activate the boundary guard pipeline within your downstream Phoenix routers and add stateful hooks like `TenantLiveMount` and `UserSocket` channel bridges.

---

## 5. Development Local Testing

* Update your `/etc/hosts` file (`127.0.0.1 tenant1.auth.mesh.local`, etc.) to map your testing subdomains locally.
* Clean build artifacts, fetch dependencies, compile, and boot your server cluster using standard Mix tasks (`mix phx.server`).
