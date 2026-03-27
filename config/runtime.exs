import Config

# 1. THE LOADER MUST RUN FIRST (Local Dev only)
if config_env() != :prod do
  env_path = Path.expand("../.env", __DIR__)

  if File.exists?(env_path) do
    IO.puts("==> STRATEGIC LOAD: #{env_path}")

    env_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.each(fn line ->
      line = String.trim(line)

      if not String.starts_with?(line, "#") and String.contains?(line, "=") do
        [key, value] = String.split(line, "=", parts: 2)

        clean_key = String.trim(key)
        clean_value = value |> String.trim() |> String.replace(~r/^["']|["']$/, "")

        System.put_env(clean_key, clean_value)
      end
    end)
  else
    IO.warn("CRITICAL: .env file NOT found at #{env_path}")
  end
end

# 2. DEBUG (After the loader)
IO.inspect(System.get_env("AFRICASTALKING_USERNAME"), label: "AFTER LOAD - USERNAME")
IO.inspect(System.get_env("AFRICASTALKING_API_KEY"), label: "AFTER LOAD - API KEY")

# 2. GENERAL APP CONFIG
if System.get_env("PHX_SERVER") do
  config :goods, GoodsWeb.Endpoint, server: true
end

port = String.to_integer(System.get_env("PORT") || "4000")

# 3. AFRICA'S TALKING CONFIGURATION
at_username = System.get_env("AFRICASTALKING_USERNAME")
at_api_key = System.get_env("AFRICASTALKING_API_KEY")

if is_nil(at_username) or is_nil(at_api_key) do
  IO.warn("""
  SMS CREDENTIALS MISSING:
  AFRICASTALKING_USERNAME: #{inspect(at_username)}
  AFRICASTALKING_API_KEY: #{if at_api_key, do: "[REDACTED]", else: "nil"}
  """)
end

africastalking_base_url =
  case {System.get_env("AFRICASTALKING_BASE_URL"), at_username} do
    {url, _} when is_binary(url) and url != "" ->
      url
    {_, "sandbox"} ->
      "https://api.sandbox.africastalking.com/version1/messaging"
    _ ->
      "https://api.africastalking.com/version1/messaging"
  end

config :goods, Logistics.Notifications.ParcelBookingSMS,
  username: at_username,
  api_key: at_api_key,
  base_url: africastalking_base_url

config :goods, :super_admin_email, System.get_env("SUPER_ADMIN_EMAIL") || "Abubakar@craftinc.dev"

# 4. PRODUCTION SPECIFIC CONFIG
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing."

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :goods, Goods.Repo,
    url: database_url,
    # --- DIGITALOCEAN SSL REQUIREMENTS ---
    ssl: true,
    ssl_opts: [verify: :verify_none],
    # --------------------------------------
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing. Use `mix phx.gen.secret`"

  host = System.get_env("PHX_HOST") || "localhost"
  url_scheme = System.get_env("PHX_URL_SCHEME") || "https" # Standard for DO
  url_port = String.to_integer(System.get_env("PHX_URL_PORT") || "443")

  config :goods, GoodsWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    # --- FIX FOR WEBSOCKET / CHECK ORIGIN ERROR ---
    check_origin: [
      "https://#{host}",
      "//#{host}",
      "https://parcel-loidc.ondigitalocean.app"
    ],
    # -----------------------------------------------
    secret_key_base: secret_key_base

  config :goods,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing TOKEN_SIGNING_SECRET")
else
  # Optional: Explicitly disable SSL for non-prod if your local DB doesn't use it
  config :goods, Goods.Repo, ssl: false

  # Default endpoint config for dev/test
  config :goods, GoodsWeb.Endpoint, http: [port: port]
end
