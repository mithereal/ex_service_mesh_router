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