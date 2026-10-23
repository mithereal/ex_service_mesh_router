# ExServiceMeshRouter

A BEAM-native service mesh gateway for Phoenix umbrella applications with automatic service discovery. Tenant handling is owned by each Phoenix application.

---

# Architecture Overview

## Request Flow

Client Request  
→ Gateway Router  
→ Service Registry (host → endpoint)  
→ Phoenix Endpoint  
→ Phoenix App Router  
→ Tenant Plug (inside app)  
→ Controllers / LiveView

---

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_service_mesh_router` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_service_mesh_router, ">= 0.0.0"}
  ]
end
```

## Configuration

```elixir
config :ex_service_mesh_router,
           port: 4000
```

# Key Design Principles

## 1. Gateway is service-only

The gateway ONLY routes by host:

- auth.local → AuthWeb.Endpoint
- billing.local → BillingWeb.Endpoint

No tenant logic exists in the gateway.

---

## 2. Phoenix apps own tenants

Each Phoenix app is responsible for:

- tenant extraction
- tenant assignment
- tenant isolation
- data scoping

---

## 3. Shared tenant resolver

A shared module provides consistent tenant parsing across apps.

---

# Project Structure

lib/
router/
application.ex
router.ex
registry.ex

shared/
tenant_resolver.ex

---

# How It Works

## 1. Service discovery

At startup, the gateway scans loaded umbrella apps and builds a routing table from Phoenix endpoint config:

Example config:

config :auth_web, AuthWeb.Endpoint,
url: [host: "auth.local", port: 4001]

Becomes:

auth.local → AuthWeb.Endpoint

---

## 2. Routing

Request:

GET http://auth.local/login

Flow:

1. Extract host header
2. Lookup endpoint in registry
3. Forward request to Phoenix endpoint

---

## 3. Tenant handling (inside Phoenix apps)

Example:

tenant1.auth.local

Inside Auth app:

- Tenant Plug extracts "tenant1"
- Assigns:

conn.assigns.tenant = "tenant1"

---

# Shared Tenant Resolver

Used by all Phoenix apps:

Router.Shared.TenantResolver.resolve("tenant1.auth.local")

---

# Configuration

## Example Phoenix app config

config :auth_web, AuthWeb.Endpoint,
url: [
host: "auth.local",
port: 4001
]

config :auth_web,
endpoint: AuthWeb.Endpoint

---

# Running the system

## Install dependencies

mix deps.get
mix compile

## Start server

mix phx.server

---

# Local DNS (development)

127.0.0.1 auth.local
127.0.0.1 billing.local

---

# Test URLs

http://auth.local:4000  
http://billing.local:4000

---

# What this does NOT do

- SSL termination
- database routing
- authentication/authorization
- circuit breaking
- tenant provisioning

These belong in:
- Phoenix apps
- infrastructure layer

---

# Mental model

A BEAM-native ingress router where:

- Gateway routes services
- Phoenix apps own tenants
- Each app is an isolated tenant runtime

## Setup Since all applications are running on the same physical node, communicating via local loopback ports (127.0.0.1) is the fastest, lowest-latency approach.
To ensure this setup works smoothly in production on a single machine, add these final node-level updates to your configurations:

1. Configure Unique Ports for Your Applications

In a single-node configuration, each application's web server must bind to its own unique local port so they do not conflict. Update each child application's configuration file (e.g., config/runtime.exs or config/config.exs):
elixir
# In Child App 1 (e.g., Billing Service)
config :billing_app, BillingApp.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001], # Binds strictly to localhost
  url: [host: "billing.local"]             # The base service domain matching the router

# In Child App 2 (e.g., Inventory Service)
config :inventory_app, InventoryApp.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "inventory.local"]
Use code with caution.

2. Configure the Central Router

The main Router is the only application that should be exposed to the outside world. It needs to listen on standard web ports (like 80 or 443, or an arbitrary public gateway port like 4000).
elixir
# In the Router App configuration
config :router, Router.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000], # Listens on all interfaces to receive public traffic
  url: [host: "localhost"]
Use code with caution.

3. Verification Check (Handling System Limits)

Because your Central Router handles connections and opens a new internal client connection to the child services over loopback, you will double the number of open sockets on the machine under load.
Make sure your host operating system has high enough file descriptor limits. You can check and set this in your deployment script or terminal session before launching the application:
bash
# Check current open files limit
ulimit -n

# Increase limits for high-concurrency routing on the node
ulimit -n 65535
Use code with caution.
Your system is now architecture-sound, fully process-isolated, and safe against cascade failures across your single-node services!