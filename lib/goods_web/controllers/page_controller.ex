defmodule GoodsWeb.PageController do
  use GoodsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def dash(conn, _params) do
    current_user = conn.assigns[:current_user]

    parcel_bookings =
      Ash.read!(Logistics.ParcelBooking,
        actor: current_user,
        tenant: current_user.company_key
      )

    total_count = length(parcel_bookings)

    recent_parcel_bookings =
      parcel_bookings
      |> Enum.take(5)

    current_scope =
      if current_user do
        %{user: current_user}
      else
        nil
      end

    conn
    |> assign(:current_scope, current_scope)
    |> assign(:total_count, total_count)
    |> assign(:recent_parcel_bookings, recent_parcel_bookings)
    |> render(:dash)
  end
end
