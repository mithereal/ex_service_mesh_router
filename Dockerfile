# --- Stage 1: Build Environment ---
FROM elixir:1.15-alpine AS builder

RUN apk add --no-cache build-base git

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

# Copy dependency configs
COPY mix.exs mix.lock ./
COPY apps/ex_service_mesh_router/mix.exs apps/ex_service_mesh_router/
COPY apps/router_shared/mix.exs apps/router_shared/
COPY apps/auth_app/mix.exs apps/auth_app/
COPY apps/chat_app/mix.exs apps/chat_app/

RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application source code
COPY . .

RUN mix compile

# --- Stage 2: Runtime Environment ---
FROM elixir:1.15-alpine AS runtime

RUN apk add --no-cache ncurses-libs libstdc++ bash

WORKDIR /app

COPY --from=builder /app /app

ENV MIX_ENV=prod

# Expose potential runtime port interfaces
EXPOSE 4000 4002 4003
