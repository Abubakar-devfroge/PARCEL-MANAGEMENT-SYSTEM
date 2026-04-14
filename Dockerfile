# ────────────────────────────────────────────────────────────────────────────────
# 1️⃣  Builder image
# ────────────────────────────────────────────────────────────────────────────────
ARG ELIXIR_VERSION=1.18.2
ARG OTP_VERSION=27.2.1
ARG DEBIAN_VERSION=bookworm-20250203-slim
ARG MIX_ENV=prod

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS builder

ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Step 1: Deps only
COPY mix.exs mix.lock ./
RUN HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120 mix deps.get --only ${MIX_ENV}

# Step 2: Config and Compile Deps (This allows caching compiled deps)
COPY config/config.exs config/${MIX_ENV}.exs ./config/
RUN mix deps.compile

# Step 3: Assets (Cached unless package.json changes)
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix assets ci --no-audit --progress=false

# Step 4: Full Source & Build
# Note: Copying assets/ last ensures code changes don't trigger re-installing npm pkgs
COPY priv priv
COPY assets assets
COPY lib lib
COPY config/runtime.exs ./config/ 
COPY rel rel

RUN mix compile && mix assets.deploy && mix release

# ────────────────────────────────────────────────────────────────────────────────
# 2️⃣  Runtime image
# ────────────────────────────────────────────────────────────────────────────────
FROM debian:${DEBIAN_VERSION} AS final

ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}   
ENV PHX_SERVER=true
# Standardize port
ENV PORT=4000 

RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
# Set permissions early
RUN chown nobody /app

# Copy release
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/goods ./

USER nobody

# Best Practice: Use the absolute path to the bin
ENTRYPOINT ["/app/bin/goods"]
CMD ["start"]