# ==========================================
# 🏗️ Stage 1: Build Environment
# ==========================================
FROM elixir:1.15-alpine AS builder

# Install core build engine elements
RUN apk add --no-cache build-base git

WORKDIR /app

# Core build parameters
ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix local.rebar --force

# Copy root umbrella tracking maps
COPY mix.exs mix.lock ./

# Copy umbrella application definition files (adjust paths if names differ locally)
COPY apps/ex_service_mesh_router/mix.exs apps/ex_service_mesh_router/
COPY apps/router_shared/mix.exs apps/router_shared/
COPY apps/auth_app/mix.exs apps/auth_app/
COPY apps/chat_app/mix.exs apps/chat_app/

# Fetch and cache dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Sync remaining project source files
COPY . .

# Compile code baseline and output optimized standalone binaries via Mix Release
RUN mix compile
RUN mix release --overwrite

# ==========================================
# 🚀 Stage 2: Runtime Environment
# ==========================================
FROM alpine:3.18 AS runtime

# Dependencies needed for standard BEAM execution and network utilities
RUN apk add --no-cache ncurses-libs libstdc++ bash openssl libgcc

WORKDIR /app

# Copy ONLY the compiled production release artifact from the builder phase
COPY --from=builder /app/_build/prod/rel /app/releases

ENV MIX_ENV=prod

# Expose routing mesh port channels
EXPOSE 4000 4002 4003

# Automatically boot the entry release context via command definitions
# Handled dynamically via Docker Compose command flags
CMD ["/app/releases/ex_service_mesh_router/bin/ex_service_mesh_router", "start"]
