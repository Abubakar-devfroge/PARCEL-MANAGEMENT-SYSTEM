# ────────────────────────────────────────────────────────────────────────────────
# 1️⃣  Builder image – contains Elixir, Erlang, Node.js and npm
# ────────────────────────────────────────────────────────────────────────────────
ARG ELIXIR_VERSION=1.19.1
ARG OTP_VERSION=28.1.1
ARG DEBIAN_VERSION=trixie-20260316-slim
ARG MIX_ENV=prod   # <‑‑ expose the build environment

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder
ENV MIX_ENV=${MIX_ENV}

# Install build‑time tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Hex & Rebar
RUN mix local.hex --force && mix local.rebar --force

# Fetch Elixir deps
COPY mix.exs mix.lock ./
RUN mix deps.get --only ${MIX_ENV} && mkdir -p config

# Compile deps (triggered by config change)
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

# Setup assets
RUN mix assets.setup

# Install npm front‑end packages
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix assets ci --no-audit --progress=false

# Rest of the source
COPY priv priv
COPY lib lib
COPY assets assets

# Compile the release
RUN mix compile
RUN mix assets.deploy
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ────────────────────────────────────────────────────────────────────────────────
# 2️⃣  Runtime image – only what the server needs
# ────────────────────────────────────────────────────────────────────────────────
FROM ${RUNNER_IMAGE} AS final
ENV MIX_ENV=${MIX_ENV}   

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
USER nobody

# Copy the compiled release – now expands MIX_ENV correctly
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/goods ./

CMD ["/app/bin/server"]
