import Config

# 1. THE LOADER MUST RUN FIRST (Local Dev only)
if true do
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

config :goods, :employee_invites,
  resend_api_key: System.get_env("RESEND_API_KEY"),
  resend_from_email: System.get_env("RESEND_FROM_EMAIL") || "BUSCAR <no-reply@buscar.app>",
  app_base_url: System.get_env("APP_BASE_URL") || "http://localhost:4000"

# 4. PRODUCTION SPECIFIC CONFIG
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing."

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing. Use `mix phx.gen.secret`"

  host = System.get_env("PHX_HOST") || "localhost"
  url_scheme = System.get_env("PHX_URL_SCHEME") || "https"
  url_port = String.to_integer(System.get_env("PHX_URL_PORT") || "443")
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # Cleaned up Repo Config (Merged)
  config :goods, Goods.Repo,
    url: database_url,
    ssl: true,
    ssl_opts: [verify: :verify_none],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Endpoint Config with FORCE_SSL for secure cookies
  config :goods, GoodsWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    # IMPORTANT: This allows cookies to work across DigitalOcean's load balancer
    force_ssl: [rewrite_on: [:x_forwarded_proto]],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    check_origin: [
      "https://#{host}",
      "https://parcel-loidc.ondigitalocean.app"
    ],
    secret_key_base: secret_key_base

  config :goods,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing TOKEN_SIGNING_SECRET")
else
  # Local Development
  config :goods, Goods.Repo, ssl: false
  config :goods, GoodsWeb.Endpoint, http: [port: port]
end
