defmodule GoodsWeb.Router do
  use GoodsWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {GoodsWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:load_from_session)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:load_from_bearer)
    plug(:set_actor, :user)
  end

  pipeline :authenticated_browser do
    plug(:require_authenticated_user)
  end

  scope "/", GoodsWeb do
    pipe_through([:browser, :authenticated_browser])

    get("/parcel_reports/export", ParcelReportExportController, :export)

    ash_authentication_live_session :authenticated_routes,
      on_mount: [{GoodsWeb.LiveUserAuth, :live_user_required}] do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {GoodsWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {GoodsWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {GoodsWeb.LiveUserAuth, :live_no_user}

      live("/dash", DashboardLive, :index)
      live("/parcel_bookings", ParcelBookingLive.Index, :index)
      live("/parcel_bookings/new", ParcelBookingLive.Form, :new)
      live("/parcel_bookings/:id/edit", ParcelBookingLive.Form, :edit)
      live("/parcel_bookings/:id", ParcelBookingLive.Show, :show)
      live("/parcel_bookings/:id/show/edit", ParcelBookingLive.Show, :edit)
      live("/parcel_reports", ParcelReportLive, :index)
      live("/profile", ProfileLive, :index)
    end

    ash_authentication_live_session :onboarding_routes,
      on_mount: [{GoodsWeb.LiveUserAuth, :live_user_required}],
      root_layout: {GoodsWeb.Layouts, :root_onboarding} do
      live("/onboarding", OnboardingLive, :index)
    end
  end

  scope "/", GoodsWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    auth_routes(AuthController, Goods.Accounts.User, path: "/auth")
    sign_out_route(AuthController)

    # Remove these if you'd like to use your own authentication views
    sign_in_route(
      register_path: "/register",
      reset_path: "/reset",
      auth_routes_prefix: "/auth",
      on_mount: [{GoodsWeb.LiveUserAuth, :live_no_user}],
      overrides: [
        GoodsWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]
    )

    # Remove this if you do not want to use the reset password feature
    reset_route(
      auth_routes_prefix: "/auth",
      overrides: [
        GoodsWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]
    )

    # Remove this if you do not use the confirmation strategy
    confirm_route(Goods.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [GoodsWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Goods.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [GoodsWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", GoodsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:goods, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:browser, :authenticated_browser])

      live_dashboard("/dashboard", metrics: GoodsWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  if Application.compile_env(:goods, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through([:browser, :authenticated_browser])

      ash_admin("/")
    end
  end

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must sign in to access this page.")
      |> Phoenix.Controller.redirect(to: "/sign-in")
      |> Plug.Conn.halt()
    end
  end
end
