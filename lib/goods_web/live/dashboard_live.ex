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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-12">
          <div class="rounded-md border border-gray-200 bg-white lg:col-span-8">
            <div class="border-b border-gray-200 px-4 py-3 sm:px-6">
              <h1 class="text-xl font-semibold text-gray-900">Dashboard</h1>
              <p class="mt-1 text-sm text-gray-500">Welcome, {@current_user.email}</p>
            </div>

            <div class="px-4 py-3 sm:px-6">
              <.link
                id="book-parcel-cta"
                navigate={~p"/parcel_bookings/new"}
                class="inline-flex items-center justify-center rounded-md bg-gray-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-gray-800"
              >
                Book Parcel
              </.link>
            </div>
          </div>

          <div class="rounded-md border border-gray-200 bg-gray-50 lg:col-span-4">
            <div class="flex items-center justify-between border-b border-gray-200 px-4 py-3 sm:px-6">
              <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
                Parcel Summary
              </h2>
              <button
                type="button"
                phx-click="refresh_totals"
                class="inline-flex items-center justify-center rounded-md bg-white px-2.5 py-2 text-gray-600 inset-ring inset-ring-gray-300 hover:bg-gray-100"
                aria-label="Refresh totals"
                title="Refresh totals"
              >
                <.icon name="hero-arrow-path" class="size-4" />
              </button>
            </div>

            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                <tr>
                  <th class="w-1/2 bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Total Parcels
                  </th>
                  <td class="px-4 py-3 text-lg font-semibold sm:px-6">{@total_count}</td>
                </tr>
                <tr>
                  <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Last Refreshed
                  </th>
                  <td class="px-4 py-3 text-gray-600 sm:px-6">
                    {format_eat_datetime(@last_refreshed_at)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="rounded-md border border-gray-200 bg-white">
          <div class="border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Daily Parcel Summary
            </h2>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50 text-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Day
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Date
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Total Parcels Booked Today
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                <tr>
                  <td class="px-4 py-3 font-medium sm:px-6">{@today_label}</td>
                  <td class="px-4 py-3 sm:px-6">{@today_date_label}</td>
                  <td class="px-4 py-3 font-semibold sm:px-6">{@booked_today_count}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
