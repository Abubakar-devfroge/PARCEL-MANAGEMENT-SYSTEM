defmodule GoodsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :goods

  # The session will be stored in the cookie and signed.
  # same_site: "Lax" is critical for DigitalOcean's redirect flows.
  @session_options [
    store: :cookie,
    key: "_goods_key",
    signing_salt: "ZMbGaLfD",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [session: @session_options]
    ],
    longpoll: [
      connect_info: [session: @session_options]
    ]

  # Serve static files from "priv/static"
  plug Plug.Static,
    at: "/",
    from: :goods,
    gzip: not code_reloading?,
    only: GoodsWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  # Custom Tidewave integration
  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  # Code reloading for development
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug AshPhoenix.Plug.CheckCodegenStatus
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :goods
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # Session plug must be before the Router
  plug Plug.Session, @session_options
  plug GoodsWeb.Router

  # Fallback logic for socket origin verification
  def check_origin(uri) do
    host = uri.host

    host == "parcel-loidc.ondigitalocean.app" or
      host == "localhost" or
      String.ends_with?(host, ".ondigitalocean.app")
  end
end
