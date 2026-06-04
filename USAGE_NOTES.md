# Usage Notes

## 1. Gateway is NOT a Phoenix app

The gateway layer is a lightweight OTP application responsible only for service routing.

- It does not use Phoenix
- It does not implement business logic
- It does not handle tenants

It only maps:

auth.local → AuthWeb.Endpoint  
billing.local → BillingWeb.Endpoint  
admin.local → AdminWeb.Endpoint

---

## 2. Phoenix apps live in umbrella `/apps`

Each service is an independent Phoenix application inside the umbrella:

apps/
auth_web/
billing_web/
tenant_web/
admin_web/

Each app:
- owns its own router
- owns its own endpoints
- owns tenant logic (if multi-tenant)
- runs independently within the same BEAM node

---

## 3. Phoenix dependency handling

The gateway may reference Phoenix indirectly via umbrella apps.

To avoid version conflicts:

- Phoenix is usually defined in child apps
- Gateway should not introduce conflicting Phoenix versions
- If Phoenix is required in deps, it must use `override: true`

---

## 4. Why Phoenix is marked override: true

If included in the gateway:

- ensures a single Phoenix version across all umbrella apps
- prevents dependency resolution conflicts
- keeps runtime consistent across services

---

## 5. Gateway dependency model

Typical gateway dependencies:

- Plug (request handling)
- Cowboy or Bandit (HTTP server)
- Logger (runtime logs)

Optional:
- Bandit (preferred modern HTTP server with future TLS/SNI support)

---

## 6. Recommended HTTP server approach

Option A: Plug + Cowboy (default)
- Stable, traditional
- Simple HTTP handling
- No advanced TLS features required at gateway level

Option B: Bandit (recommended future path)
- Better performance
- SNI support
- Future TLS control

---

## 7. Running the gateway via Bandit

Instead of running under Phoenix, the gateway can be started directly:

Bandit.start_link(
plug: ExServiceMeshRouter.Router,
port: 4000
)

This makes the gateway:
- fully independent
- minimal overhead
- easy to place behind reverse proxies

---

## 8. Deployment model

Client
→ HTTPS
Reverse Proxy (Nginx / Caddy / Traefik)
→ HTTP
Gateway (ExServiceMeshRouter)
→ Phoenix Apps (Auth / Billing / Admin)

---

## 9. Role separation summary

| Layer | Responsibility |
|------|----------------|
| Reverse Proxy | SSL termination, routing to gateway |
| Gateway | Service-level routing only |
| Phoenix apps | Business logic + tenant handling |
| Shared libs | Cross-app utilities (tenant parsing, etc.) |

---

## 10. Key constraint

The gateway must remain:

- stateless in business logic
- unaware of tenants
- focused only on host → endpoint resolution

All tenant resolution MUST occur inside Phoenix applications.