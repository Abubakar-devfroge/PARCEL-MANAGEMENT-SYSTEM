# ────────────────────────────────────────────────────────────────────────────────
# 1️⃣  Builder image – contains Elixir, Erlang, Node.js and npm
# ────────────────────────────────────────────────────────────────────────────────
ARG ELIXIR_VERSION=1.19.1
ARG OTP_VERSION=28.1.1
ARG DEBIAN_VERSION=trixie-20260316-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build‑time tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------- #
# Prepare the build dir, install Hex & Rebar, and fetch Elixir deps.
# --------------------------------------------------------------------- #
WORKDIR /app
ENV MIX_ENV="prod"

# Install Hex & Rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy the mix manifest files and fetch deps
COPY mix.exs mix.lock ./
RUN mix deps.get --only ${MIX_ENV} && mkdir -p config

# Copy compile‑time config and compile the deps
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# --------------------------------------------------------------------- #
# Build the JavaScript assets.  Use 'npm ci' so the lock file is honored.
# --------------------------------------------------------------------- #
RUN mix assets.setup

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix assets ci --no-audit --progress=false

# --------------------------------------------------------------------- #
# Copy the rest of the source, compile Elixir and assets, then make the
# release.
# --------------------------------------------------------------------- #
COPY priv priv
COPY lib lib
COPY assets assets

RUN mix compile
RUN mix assets.deploy

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ────────────────────────────────────────────────────────────────────────────────
# 2️⃣  RUNTIME image – only what the server needs
# ────────────────────────────────────────────────────────────────────────────────
FROM ${RUNNER_IMAGE} AS final

# Install runtime libraries
RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Set a user that doesn't need root privileges
USER nobody

# Copy the compiled release from the builder stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/goods ./

# Entrypoint & CMD
# Uncomment the next two lines if you want to run tini as an init process
# RUN apt-get update && apt-get install -y --no-install-recommends tini && rm -rf /var/lib/apt/lists/*
# ENTRYPOINT ["/tini", "--"]
CMD ["/app/bin/server"]
