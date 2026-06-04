# Service Mesh Router (Phoenix Multi-App Mesh System)

A compile-time + runtime service mesh built in Elixir that discovers multiple Phoenix apps, generates routing manifests, and unifies HTTP + WebSocket traffic through a central router application.

---

# 🧭 Overview

This system consists of three layers:

- apps/ → Phoenix applications (service providers)
- router/ → standalone OTP application (control plane + runtime router)
- shared/ → contract schemas + validation tooling

The router:
- scans all apps
- introspects routes + channels
- generates manifests
- builds a global routing index
- routes HTTP + WebSocket traffic

---

# 🏗 Architecture

apps/        → Phoenix services (app_a, app_b, ...)
router/      → service mesh runtime + compiler
shared/      → schemas + validation rules

---

# ⚙️ Installation

## 1. Clone repository

git clone <repo_url>
cd service-mesh-router

---

## 2. Fetch dependencies

cd router
mix deps.get

---

## 3. Compile system

mix compile

---

## 4. Run router

mix run --no-halt

Or production:

MIX_ENV=prod mix release

---

# 🧠 How it works

## 1. App discovery

Router scans:

apps/*

Each app must contain:

- lib/
- priv/manifest.json (generated)

---

## 2. Manifest generation (mesh compiler)

Run manually:

mix mesh.compile

What it does:
1. Scans all apps
2. Introspects Phoenix routers + channels
3. Builds normalized manifest
4. Writes output into:

apps/app_a/priv/manifest.json
apps/app_b/priv/manifest.json

---

## 3. Manifest structure

{
"app": "app_a",
"version": 1,
"domains": ["localhost"],
"http": {
"/api/users": ["GET", "POST"],
"/api/health": ["GET"]
},
"ws": {
"topics": [
"room:*",
"user:*"
]
}
}

---

## 4. Runtime aggregation

Router builds:

router/priv/cache/manifests.json

This becomes the global routing index:
- HTTP route → app mapping
- WS topic → app mapping
- domain → app mapping

---

## 5. HTTP routing

Client → router → manifest lookup → forward to Phoenix app

Matching:
routing_index.http[path]

---

## 6. WebSocket routing

Client → router → topic_router → app session

Matching:
routing_index.ws[topic]

---

# 🔄 Mesh compilation

Run:

mix mesh.compile

Pipeline:

scanner → introspector → builder → diff → writer

Outputs:
- apps/*/priv/manifest.json
- router cache registry

---

# 📦 Shared contracts

router/lib/ex_service_mesh_router/shared/

Contains:
- manifest schema validation
- protocol rules
- diff utilities

---

# 🧪 Testing

mix test

Layers:
- test/mesh/
- test/discovery/
- test/routing/
- test/integration/

---

# 🚦 Key commands

Compile manifests:
mix mesh.compile

Run router:
mix run --no-halt

Run tests:
mix test

---

# 🧠 Design principles

- apps are passive services
- router is control plane + runtime
- manifests are source of truth
- routing is data-driven
- no runtime introspection required

---

# 🔥 Capabilities

- Multi-app Phoenix discovery
- Unified HTTP routing
- WebSocket routing
- Compile-time manifest generation
- Runtime routing index
- Diff-based architecture
- Rollback-ready design

---
