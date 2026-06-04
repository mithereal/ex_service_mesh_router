router/
└── lib/
└── ex_service_mesh_router/
│
├── mesh/                          # 🧠 COMPILER (build-time)
│   ├── scanner.ex
│   ├── introspector.ex
│   ├── manifest_builder.ex
│   ├── diff.ex
│   ├── writer.ex
│   ├── compiler.ex
│   └── task.ex
│
├── discovery/                     # 🧭 CONTROL PLANE (runtime registry)
│   ├── auto_registry.ex
│   ├── manifest_store.ex
│   ├── manifest_sync.ex
│   ├── manifest_diff.ex
│   ├── manifest_versions.ex
│   └── manifest_rollback.ex
│
├── routing/                       # 🚦 ROUTING ENGINE
│   ├── app_router.ex
│   ├── topic_router.ex
│   ├── context.ex
│   └── validation.ex
│
├── bridge/                        # 🌉 EXECUTION / DATA PLANE
│   ├── http_forwarder.ex
│   ├── ws_supervisor.ex
│   ├── ws_session.ex
│   └── session.ex
│
├── transport/                     # 📡 CLIENT TRANSPORT
│   └── ws_client.ex
│
├── protocol/                      # 📦 FRAME + MESSAGE FORMAT
│   ├── builder.ex
│   ├── frame.ex
│   └── validator.ex
│
├── core/                          # ⚙️ INTERNAL EVENT SYSTEM
│   ├── event_bus.ex
│   └── mesh_event.ex
│
├── utils/                         # 🧰 HELPERS
│   ├── time.ex
│   ├── id.ex
│   └── validate.ex
│
├── shared/                       # 📜 CONTRACT + GOVERNANCE LAYER
│   ├── tooling/
│   │   ├── manifest_validator.ex
│   │   ├── diff_tool.ex
│   │   └── schema_utils.ex
│   │
│   └── mesh_contracts/
│       ├── manifest_schema.json
│       ├── protocol_schema.json
│       └── routing_contracts.json
│
├── router.ex                      # Plug HTTP entrypoint
└── application.ex                # OTP root supervisor