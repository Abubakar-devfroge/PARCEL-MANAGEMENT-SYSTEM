defmodule GoodsWeb.ParcelReportLive do
  use GoodsWeb, :live_view

  @refresh_interval 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh_reports, @refresh_interval)
    end

    filters = default_filters()
    parcel_bookings = list_parcel_bookings(socket)
    filtered_bookings = apply_filters(parcel_bookings, filters)
    report_data = build_report_data(filtered_bookings)

    {:ok,
     socket
     |> assign(:page_title, "Parcel Management Reports")
     |> assign(:filters, filters)
     |> assign(:all_bookings_count, length(parcel_bookings))
     |> assign(:filtered_bookings_count, length(filtered_bookings))
     |> assign(:filtered_bookings, filtered_bookings)
     |> assign(:report_data, report_data)
     |> assign(:alerts, build_alerts(report_data, filtered_bookings))
     |> assign(:last_updated_at, DateTime.utc_now())
     |> stream(:custom_rows, filtered_bookings)}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters = normalize_filters(params)
    {:noreply, refresh_report_assigns(socket, filters)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    {:noreply, refresh_report_assigns(socket, default_filters())}
  end

  @impl true
  def handle_info(:refresh_reports, socket) do
    Process.send_after(self(), :refresh_reports, @refresh_interval)

    {:noreply, refresh_report_assigns(socket, socket.assigns.filters)}
  end

  defp refresh_report_assigns(socket, filters) do
    parcel_bookings = list_parcel_bookings(socket)
    filtered_bookings = apply_filters(parcel_bookings, filters)
    report_data = build_report_data(filtered_bookings)

    socket
    |> assign(:filters, filters)
    |> assign(:all_bookings_count, length(parcel_bookings))
    |> assign(:filtered_bookings_count, length(filtered_bookings))
    |> assign(:filtered_bookings, filtered_bookings)
    |> assign(:report_data, report_data)
    |> assign(:alerts, build_alerts(report_data, filtered_bookings))
    |> assign(:last_updated_at, DateTime.utc_now())
    |> stream(:custom_rows, filtered_bookings, reset: true)
  end

  defp default_filters do
    %{
      query: "",
      parcel_number: "",
      sender: "",
      receiver: "",
      parcel_type: "",
      date_from: "",
      date_to: ""
    }
  end

  defp normalize_filters(params) do
    %{
      query: normalize_text(Map.get(params, "query")),
      parcel_number: normalize_text(Map.get(params, "parcel_number")),
      sender: normalize_text(Map.get(params, "sender")),
      receiver: normalize_text(Map.get(params, "receiver")),
      parcel_type: normalize_text(Map.get(params, "parcel_type")),
      date_from: normalize_text(Map.get(params, "date_from")),
      date_to: normalize_text(Map.get(params, "date_to"))
    }
  end

  defp normalize_text(nil), do: ""
  defp normalize_text(value), do: value |> to_string() |> String.trim()

  defp list_parcel_bookings(socket) do
    Ash.read!(Logistics.ParcelBooking, actor: socket.assigns.current_user)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp apply_filters(parcel_bookings, filters) do
    Enum.filter(parcel_bookings, fn booking ->
      text_match?(booking, filters.query) and
        text_match?(booking.parcel_number, filters.parcel_number) and
        text_match?([booking.sender_name, booking.sender_phone], filters.sender) and
        text_match?([booking.receiver_name, booking.receiver_phone], filters.receiver) and
        text_match?(booking.parcel_type, filters.parcel_type) and
        date_match?(booking.inserted_at, filters.date_from, filters.date_to)
    end)
  end

  defp text_match?(_value, ""), do: true

  defp text_match?(value, query) when is_list(value) do
    normalized_query = String.downcase(query)

    Enum.any?(value, fn item ->
      item
      |> to_string()
      |> String.downcase()
      |> String.contains?(normalized_query)
    end)
  end

  defp text_match?(booking, query) when is_map(booking) do
    normalized_query = String.downcase(query)

    [
      booking.parcel_number,
      booking.sender_name,
      booking.sender_phone,
      booking.receiver_name,
      booking.receiver_phone,
      booking.destination,
      booking.parcel_type
    ]
    |> Enum.any?(fn item ->
      item
      |> to_string()
      |> String.downcase()
      |> String.contains?(normalized_query)
    end)
  end

  defp text_match?(value, query) do
    value
    |> to_string()
    |> String.downcase()
    |> String.contains?(String.downcase(query))
  end

  defp date_match?(inserted_at, "", ""), do: not is_nil(inserted_at)

  defp date_match?(inserted_at, date_from, date_to) do
    with %Date{} = booking_date <- datetime_to_date(inserted_at),
         {:ok, from_date} <- optional_date(date_from),
         {:ok, to_date} <- optional_date(date_to) do
      after_start? = is_nil(from_date) or Date.compare(booking_date, from_date) in [:eq, :gt]
      before_end? = is_nil(to_date) or Date.compare(booking_date, to_date) in [:eq, :lt]
      after_start? and before_end?
    else
      _ -> false
    end
  end

  defp optional_date(""), do: {:ok, nil}

  defp optional_date(value) do
    Date.from_iso8601(value)
  end

  defp datetime_to_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp datetime_to_date(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_date(datetime)
  defp datetime_to_date(_), do: nil

  defp build_report_data(filtered_bookings) do
    total_count = length(filtered_bookings)
    today = Date.utc_today()
    {current_year, current_week} = :calendar.iso_week_number(Date.to_erl(today))

    daily_count =
      Enum.count(filtered_bookings, fn booking ->
        datetime_to_date(booking.inserted_at) == today
      end)

    weekly_count =
      Enum.count(filtered_bookings, fn booking ->
        case datetime_to_date(booking.inserted_at) do
          nil -> false
          date -> :calendar.iso_week_number(Date.to_erl(date)) == {current_year, current_week}
        end
      end)

    monthly_count =
      Enum.count(filtered_bookings, fn booking ->
        case datetime_to_date(booking.inserted_at) do
          nil -> false
          date -> date.year == today.year and date.month == today.month
        end
      end)

    sender_totals =
      filtered_bookings
      |> Enum.group_by(& &1.sender_phone)
      |> map_totals()

    receiver_totals =
      filtered_bookings
      |> Enum.group_by(& &1.receiver_phone)
      |> map_totals()

    top_customers =
      filtered_bookings
      |> Enum.group_by(fn booking -> {booking.sender_name, booking.sender_phone} end)
      |> Enum.map(fn {{sender_name, sender_phone}, bookings} ->
        %{
          sender_name: sender_name,
          sender_phone: sender_phone,
          total_shipments: length(bookings),
          total_revenue: sum_prices(bookings)
        }
      end)
      |> Enum.sort_by(&{&1.total_shipments, &1.total_revenue}, :desc)
      |> Enum.take(10)

    revenue_by_type =
      filtered_bookings
      |> Enum.group_by(& &1.parcel_type)
      |> Enum.map(fn {parcel_type, bookings} ->
        %{parcel_type: parcel_type, revenue: sum_prices(bookings), shipments: length(bookings)}
      end)
      |> Enum.sort_by(&{&1.revenue, &1.shipments}, :desc)

    revenue_by_location =
      filtered_bookings
      |> Enum.group_by(& &1.destination)
      |> Enum.map(fn {destination, bookings} ->
        %{destination: destination, revenue: sum_prices(bookings), shipments: length(bookings)}
      end)
      |> Enum.sort_by(&{&1.revenue, &1.shipments}, :desc)

    route_counts =
      filtered_bookings
      |> Enum.group_by(& &1.destination)
      |> Enum.map(fn {destination, bookings} ->
        %{destination: destination, total_routes: length(bookings)}
      end)
      |> Enum.sort_by(& &1.total_routes, :desc)

    total_quantity =
      Enum.reduce(filtered_bookings, 0, fn booking, acc -> acc + (booking.quantity || 0) end)

    avg_volume =
      if total_count == 0 do
        0.0
      else
        Float.round(total_quantity / total_count, 2)
      end

    pending_amount = sum_prices(filtered_bookings)

    %{
      parcel_activity: %{
        total_shipments: total_count,
        daily_shipments: daily_count,
        weekly_shipments: weekly_count,
        monthly_shipments: monthly_count,
        cancelled_shipments: 0,
        returned_shipments: 0
      },
      customer_reports: %{
        sender_totals: sender_totals,
        receiver_totals: receiver_totals,
        top_customers: top_customers
      },
      financial_reports: %{
        revenue_by_type: revenue_by_type,
        revenue_by_location: revenue_by_location,
        pending_payments_count: total_count,
        pending_payments_amount: pending_amount
      },
      operational_reports: %{
        average_volume: avg_volume,
        employee_handling: [%{employee: "Unassigned", total_shipments: total_count}],
        route_counts: route_counts
      }
    }
  end

  defp map_totals(grouped_data) do
    grouped_data
    |> Enum.map(fn {key, bookings} -> %{key: key, total_shipments: length(bookings)} end)
    |> Enum.sort_by(& &1.total_shipments, :desc)
    |> Enum.take(10)
  end

  defp sum_prices(bookings) do
    Enum.reduce(bookings, Decimal.new("0"), fn booking, acc ->
      Decimal.add(acc, normalize_decimal(booking.price))
    end)
  end

  defp normalize_decimal(%Decimal{} = value), do: value
  defp normalize_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp normalize_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp normalize_decimal(_), do: Decimal.new("0")

  defp decimal_to_money(value) do
    value
    |> normalize_decimal()
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp build_alerts(report_data, filtered_bookings) do
    pending_count = report_data.financial_reports.pending_payments_count

    []
    |> maybe_add_alert(
      filtered_bookings == [],
      :warning,
      "No records match your current report filters"
    )
    |> maybe_add_alert(
      pending_count > 0,
      :info,
      "#{pending_count} shipments are pending payment tracking based on current data"
    )
  end

  defp maybe_add_alert(alerts, true, level, message),
    do: [%{level: level, message: message} | alerts]

  defp maybe_add_alert(alerts, false, _level, _message), do: alerts

  defp format_eat_datetime(nil), do: "—"

  defp format_eat_datetime(%DateTime{} = utc_datetime) do
    utc_datetime
    |> DateTime.add(3 * 60 * 60, :second)
    |> Calendar.strftime("%d %b %Y %H:%M")
  end

  defp format_eat_datetime(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> NaiveDateTime.add(3 * 60 * 60, :second)
    |> Calendar.strftime("%d %b %Y %H:%M")
  end

  defp format_eat_datetime(_), do: "—"

  defp alert_class(:warning), do: "border-amber-200 bg-amber-50 text-amber-800"
  defp alert_class(:info), do: "border-blue-200 bg-blue-50 text-blue-800"

  defp export_path(report, format, filters) do
    normalized_filters =
      Enum.into(filters, %{}, fn {key, value} -> {to_string(key), to_string(value || "")} end)

    query =
      Plug.Conn.Query.encode(%{
        "report" => report,
        "format" => format,
        "filters" => normalized_filters
      })

    "/parcel_reports/export?" <> query
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
        <div class="rounded-md border border-gray-200 bg-white">
          <div class="border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div>
                <h1 class="text-xl font-semibold text-gray-900">Parcel Management Reports</h1>
                <p class="mt-1 text-sm text-gray-500">
                  Live operational and financial reporting from parcel bookings
                </p>
              </div>

              <div class="text-sm text-gray-500">
                Last updated: {format_eat_datetime(@last_updated_at)}
              </div>
            </div>
          </div>

          <div class="px-4 py-4 sm:px-6">
            <form
              id="reports-filter-form"
              phx-change="filter"
              class="grid grid-cols-1 gap-3 lg:grid-cols-6"
            >
              <.input
                name="filters[query]"
                value={@filters.query}
                type="search"
                label="Search"
                phx-debounce="300"
                placeholder="Parcel, sender, receiver"
              />

              <.input
                name="filters[parcel_number]"
                value={@filters.parcel_number}
                type="text"
                label="Parcel Number"
                phx-debounce="300"
              />

              <.input
                name="filters[sender]"
                value={@filters.sender}
                type="text"
                label="Sender"
                phx-debounce="300"
              />

              <.input
                name="filters[receiver]"
                value={@filters.receiver}
                type="text"
                label="Receiver"
                phx-debounce="300"
              />

              <.input
                name="filters[parcel_type]"
                value={@filters.parcel_type}
                type="text"
                label="Type"
                phx-debounce="300"
              />

              <div class="grid grid-cols-2 gap-3 lg:col-span-1">
                <.input name="filters[date_from]" value={@filters.date_from} type="date" label="From" />
                <.input name="filters[date_to]" value={@filters.date_to} type="date" label="To" />
              </div>
            </form>

            <div class="mt-3 flex items-center justify-between">
              <p class="text-sm text-gray-600">
                Showing {@filtered_bookings_count} of {@all_bookings_count} bookings
              </p>

              <button
                id="reset-reports-filters"
                type="button"
                phx-click="reset_filters"
                class="inline-flex items-center justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-700 inset-ring inset-ring-gray-300 transition hover:bg-gray-50"
              >
                Reset filters
              </button>
            </div>
          </div>
        </div>

        <div
          :for={alert <- @alerts}
          class={["rounded-md border px-4 py-3 text-sm", alert_class(alert.level)]}
        >
          {alert.message}
        </div>

        <div class="rounded-md border border-gray-200 bg-white">
          <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Parcel Activity Reports
            </h2>

            <div class="flex gap-2">
              <.link
                id="export-activity-csv"
                href={export_path("activity", "csv", @filters)}
                class="inline-flex rounded-md bg-white px-3 py-2 text-xs font-semibold text-gray-700 inset-ring inset-ring-gray-300 hover:bg-gray-50"
              >
                Export CSV
              </.link>
              <.link
                id="export-activity-excel"
                href={export_path("activity", "excel", @filters)}
                class="inline-flex rounded-md bg-gray-900 px-3 py-2 text-xs font-semibold text-white hover:bg-gray-800"
              >
                Export Excel
              </.link>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                <tr>
                  <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Daily Shipments
                  </th>
                  <td class="px-4 py-3 sm:px-6">{@report_data.parcel_activity.daily_shipments}</td>
                </tr>
                <tr>
                  <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Weekly Shipments
                  </th>
                  <td class="px-4 py-3 sm:px-6">{@report_data.parcel_activity.weekly_shipments}</td>
                </tr>
                <tr>
                  <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Monthly Shipments
                  </th>
                  <td class="px-4 py-3 sm:px-6">{@report_data.parcel_activity.monthly_shipments}</td>
                </tr>
                <tr>
                  <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Cancelled Parcels
                  </th>
                  <td class="px-4 py-3 sm:px-6">
                    {@report_data.parcel_activity.cancelled_shipments}
                  </td>
                </tr>
                <tr>
                  <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700 sm:px-6">
                    Returned Parcels
                  </th>
                  <td class="px-4 py-3 sm:px-6">{@report_data.parcel_activity.returned_shipments}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="rounded-md border border-gray-200 bg-white">
          <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Customer-Focused Reports
            </h2>

            <div class="flex gap-2">
              <.link
                id="export-customers-csv"
                href={export_path("customers", "csv", @filters)}
                class="inline-flex rounded-md bg-white px-3 py-2 text-xs font-semibold text-gray-700 inset-ring inset-ring-gray-300 hover:bg-gray-50"
              >
                Export CSV
              </.link>
              <.link
                id="export-customers-excel"
                href={export_path("customers", "excel", @filters)}
                class="inline-flex rounded-md bg-gray-900 px-3 py-2 text-xs font-semibold text-white hover:bg-gray-800"
              >
                Export Excel
              </.link>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-4 border-b border-gray-200 px-4 py-4 sm:grid-cols-2 sm:px-6">
            <div class="rounded-md border border-gray-200 bg-gray-50 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                Sender Totals (Top 10)
              </p>
              <p class="mt-1 text-lg font-semibold text-gray-900">
                {length(@report_data.customer_reports.sender_totals)}
              </p>
            </div>
            <div class="rounded-md border border-gray-200 bg-gray-50 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                Receiver Totals (Top 10)
              </p>
              <p class="mt-1 text-lg font-semibold text-gray-900">
                {length(@report_data.customer_reports.receiver_totals)}
              </p>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50 text-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Sender
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Phone
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Total Shipments
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Revenue
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                <tr :for={row <- @report_data.customer_reports.top_customers}>
                  <td class="px-4 py-3 font-medium sm:px-6">{row.sender_name}</td>
                  <td class="px-4 py-3 sm:px-6">{row.sender_phone}</td>
                  <td class="px-4 py-3 sm:px-6">{row.total_shipments}</td>
                  <td class="px-4 py-3 sm:px-6">KES {decimal_to_money(row.total_revenue)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="rounded-md border border-gray-200 bg-white">
          <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Financial Reports
            </h2>

            <div class="flex gap-2">
              <.link
                id="export-financial-csv"
                href={export_path("financial", "csv", @filters)}
                class="inline-flex rounded-md bg-white px-3 py-2 text-xs font-semibold text-gray-700 inset-ring inset-ring-gray-300 hover:bg-gray-50"
              >
                Export CSV
              </.link>
              <.link
                id="export-financial-excel"
                href={export_path("financial", "excel", @filters)}
                class="inline-flex rounded-md bg-gray-900 px-3 py-2 text-xs font-semibold text-white hover:bg-gray-800"
              >
                Export Excel
              </.link>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-4 border-b border-gray-200 px-4 py-4 sm:grid-cols-2 sm:px-6">
            <div class="rounded-md border border-gray-200 bg-gray-50 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                Pending Payments
              </p>
              <p class="mt-1 text-lg font-semibold text-gray-900">
                {@report_data.financial_reports.pending_payments_count}
              </p>
            </div>
            <div class="rounded-md border border-gray-200 bg-gray-50 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                Pending Amount
              </p>
              <p class="mt-1 text-lg font-semibold text-gray-900">
                KES {decimal_to_money(@report_data.financial_reports.pending_payments_amount)}
              </p>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-4 px-4 py-4 lg:grid-cols-2 sm:px-6">
            <div class="overflow-x-auto rounded-md border border-gray-200">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50 text-gray-700">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                      Parcel Type
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                      Shipments
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                      Revenue
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                  <tr :for={row <- @report_data.financial_reports.revenue_by_type}>
                    <td class="px-4 py-3">{row.parcel_type}</td>
                    <td class="px-4 py-3">{row.shipments}</td>
                    <td class="px-4 py-3">KES {decimal_to_money(row.revenue)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="overflow-x-auto rounded-md border border-gray-200">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50 text-gray-700">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                      Destination
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                      Shipments
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                      Revenue
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                  <tr :for={row <- @report_data.financial_reports.revenue_by_location}>
                    <td class="px-4 py-3">{row.destination}</td>
                    <td class="px-4 py-3">{row.shipments}</td>
                    <td class="px-4 py-3">KES {decimal_to_money(row.revenue)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="rounded-md border border-gray-200 bg-white">
          <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Operational Efficiency Reports
            </h2>

            <div class="flex gap-2">
              <.link
                id="export-operations-csv"
                href={export_path("operations", "csv", @filters)}
                class="inline-flex rounded-md bg-white px-3 py-2 text-xs font-semibold text-gray-700 inset-ring inset-ring-gray-300 hover:bg-gray-50"
              >
                Export CSV
              </.link>
              <.link
                id="export-operations-excel"
                href={export_path("operations", "excel", @filters)}
                class="inline-flex rounded-md bg-gray-900 px-3 py-2 text-xs font-semibold text-white hover:bg-gray-800"
              >
                Export Excel
              </.link>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-4 border-b border-gray-200 px-4 py-4 sm:grid-cols-2 sm:px-6">
            <div class="rounded-md border border-gray-200 bg-gray-50 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                Average Volume
              </p>
              <p class="mt-1 text-lg font-semibold text-gray-900">
                {@report_data.operational_reports.average_volume}
              </p>
            </div>
            <div class="rounded-md border border-gray-200 bg-gray-50 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-600">
                Employee Handling
              </p>
              <p class="mt-1 text-lg font-semibold text-gray-900">
                {hd(@report_data.operational_reports.employee_handling).total_shipments}
              </p>
            </div>
          </div>

          <div class="overflow-x-auto px-4 py-4 sm:px-6">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50 text-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                    Route
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide">
                    Shipment Count
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                <tr :for={row <- @report_data.operational_reports.route_counts}>
                  <td class="px-4 py-3">{row.destination}</td>
                  <td class="px-4 py-3">{row.total_routes}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="rounded-md border border-gray-200 bg-white">
          <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-3 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Custom / Ad-Hoc Reports
            </h2>

            <div class="flex gap-2">
              <.link
                id="export-custom-csv"
                href={export_path("custom", "csv", @filters)}
                class="inline-flex rounded-md bg-white px-3 py-2 text-xs font-semibold text-gray-700 inset-ring inset-ring-gray-300 hover:bg-gray-50"
              >
                Export CSV
              </.link>
              <.link
                id="export-custom-excel"
                href={export_path("custom", "excel", @filters)}
                class="inline-flex rounded-md bg-gray-900 px-3 py-2 text-xs font-semibold text-white hover:bg-gray-800"
              >
                Export Excel
              </.link>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50 text-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Parcel
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Sender
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Receiver
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Destination
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Type
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Qty
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Price
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide sm:px-6">
                    Booked
                  </th>
                </tr>
              </thead>
              <tbody
                id="custom_reports_rows"
                phx-update="stream"
                class="divide-y divide-gray-200 bg-white text-gray-900"
              >
                <tr :for={{id, booking} <- @streams.custom_rows} id={id}>
                  <td class="px-4 py-3 font-medium sm:px-6">{booking.parcel_number}</td>
                  <td class="px-4 py-3 sm:px-6">{booking.sender_name}</td>
                  <td class="px-4 py-3 sm:px-6">{booking.receiver_name}</td>
                  <td class="px-4 py-3 sm:px-6">{booking.destination}</td>
                  <td class="px-4 py-3 sm:px-6">{booking.parcel_type}</td>
                  <td class="px-4 py-3 sm:px-6">{booking.quantity}</td>
                  <td class="px-4 py-3 sm:px-6">KES {decimal_to_money(booking.price)}</td>
                  <td class="px-4 py-3 sm:px-6">{format_eat_datetime(booking.inserted_at)}</td>
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
