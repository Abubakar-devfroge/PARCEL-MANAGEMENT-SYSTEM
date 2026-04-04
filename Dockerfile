# ────────────────────────────────────────────────────────────────────────────────
# 1️⃣  Builder image
# ────────────────────────────────────────────────────────────────────────────────
ARG ELIXIR_VERSION=1.18
ARG OTP_VERSION=26.2.3
ARG DEBIAN_VERSION=bookworm-20240130-slim
ARG MIX_ENV=prod

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS builder

# We must redeclare ARGs inside the stage to use them
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}

# Install build‑time tools (build-essential is required for picosat/bcrypt)
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Hex & Rebar
RUN mix local.hex --force && mix local.rebar --force

# Fetch Elixir deps
COPY mix.exs mix.lock ./
# FIX: Added timeout and concurrency for picosat_elixir
RUN HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120 mix deps.get --only ${MIX_ENV}

# Copy config BEFORE deps.compile so it knows the prod settings
COPY config config
RUN mix deps.compile

# Setup assets & Install npm packages
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix assets ci --no-audit --progress=false

# Copy rest of source
COPY priv priv
COPY lib lib
COPY assets assets

# Compile the release
# 1. Compile code
RUN mix compile
# 2. Deploy assets (Tailwind/Esbuild)
RUN mix assets.deploy
# 3. Handle runtime config and release
COPY rel rel
RUN mix release

# ────────────────────────────────────────────────────────────────────────────────
# 2️⃣  Runtime image
# ────────────────────────────────────────────────────────────────────────────────
FROM debian:${DEBIAN_VERSION} AS final

# Redecalre ARG for the final stage
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}   
ENV PHX_SERVER=true

# Install runtime libraries
RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

# Copy the compiled release
# Note: Ensure 'goods' matches your app name in mix.exs
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/goods ./

USER nobody

# Start the app using the release script
CMD ["/app/bin/goods", "start"]