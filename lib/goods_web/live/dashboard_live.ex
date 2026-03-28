defmodule GoodsWeb.DashboardLive do
  use GoodsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:last_refreshed_at, nil)
     |> load_dashboard_data()}
  end

  @impl true
  def handle_event("refresh_totals", _params, socket) do
    {:noreply,
     socket
     |> load_dashboard_data()
     |> put_flash(:info, "Dashboard totals refreshed")}
  end

  defp load_dashboard_data(socket) do
    parcel_bookings = Ash.read!(Logistics.ParcelBooking, actor: socket.assigns.current_user)
    today = Date.utc_today()

    booked_today_count =
      parcel_bookings
      |> Enum.count(fn parcel_booking ->
        case parcel_booking.inserted_at do
          %DateTime{} = inserted_at -> DateTime.to_date(inserted_at) == today
          %NaiveDateTime{} = inserted_at -> NaiveDateTime.to_date(inserted_at) == today
          _ -> false
        end
      end)

    socket
    |> assign(:total_count, length(parcel_bookings))
    |> assign(:booked_today_count, booked_today_count)
    |> assign(:today_label, Calendar.strftime(today, "%A"))
    |> assign(:today_date_label, Calendar.strftime(today, "%d %b %Y"))
    |> assign(:last_refreshed_at, DateTime.utc_now())
  end

  defp format_eat_datetime(nil), do: "—"

  defp format_eat_datetime(%DateTime{} = utc_datetime) do
    utc_datetime
    |> DateTime.add(3 * 60 * 60, :second)
    |> Calendar.strftime("%d %b %Y %H:%M")
  end


end
