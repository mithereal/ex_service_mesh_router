# ExServiceMeshRouter

A BEAM-native service mesh gateway for Phoenix umbrella applications with automatic service discovery. Tenant handling is owned by each Phoenix application.

---

# Architecture Overview

## Request Flow
```text
Client Request  
→ Gateway Router (Dual HTTP & WebSocket Interceptor via Router.Router)
→ Service Registry (Extracts host → Resolves proxy network upstream string via Router.Registry)  
→ Bandit Web Server Proxying (via ReverseProxyPlug / ReverseProxyPlugWebsocket)
→ Target Phoenix Application Endpoint (e.g., localhost:4002)
→ Phoenix App Router  
→ Shared Tenant Plug (Inside the child application runtime context)  
→ Controllers / LiveView / Ash / Ecto Isolated Database Boundary
```