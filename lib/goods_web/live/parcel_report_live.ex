defmodule GoodsWeb.ParcelReportLive do
  use GoodsWeb, :live_view

  @refresh_interval 30_000
  @valid_tabs ["summary", "analytics", "customers", "financial", "shipments"]

  @impl true
  def mount(_params, _session, socket) do
    if admin?(socket.assigns[:current_user]) do
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
       |> assign(:active_tab, "summary")
       |> assign(:filters, filters)
       |> assign(:all_bookings_count, length(parcel_bookings))
       |> assign(:filtered_bookings_count, length(filtered_bookings))
       |> assign(:filtered_bookings, filtered_bookings)
       |> assign(:report_data, report_data)
       |> assign(:chart_payload, build_chart_payload(report_data, filtered_bookings))
       |> assign(:alerts, build_alerts(report_data, filtered_bookings))
       |> assign(:last_updated_at, DateTime.now!("Africa/Nairobi"))
       |> stream(:custom_rows, filtered_bookings)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Only admins can access reports")
       |> redirect(to: ~p"/dash")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    active_tab = params |> Map.get("tab") |> normalize_tab()

    {:noreply, assign(socket, :active_tab, active_tab)}
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
    |> assign(:chart_payload, build_chart_payload(report_data, filtered_bookings))
    |> assign(:alerts, build_alerts(report_data, filtered_bookings))
    |> assign(:last_updated_at, DateTime.now!("Africa/Nairobi"))
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
    Ash.read!(Logistics.ParcelBooking,
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_user.company_key
    )
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

  defp build_chart_payload(report_data, filtered_bookings) do
    activity = report_data.parcel_activity

    %{
      activity_distribution: %{
        labels: ["Daily", "Weekly", "Monthly"],
        values: [activity.daily_shipments, activity.weekly_shipments, activity.monthly_shipments]
      },
      revenue_by_type: %{
        labels:
          Enum.map(Enum.take(report_data.financial_reports.revenue_by_type, 6), & &1.parcel_type),
        values:
          Enum.map(Enum.take(report_data.financial_reports.revenue_by_type, 6), fn row ->
            decimal_to_float(row.revenue)
          end)
      },
      shipments_by_route: %{
        labels:
          Enum.map(Enum.take(report_data.operational_reports.route_counts, 8), & &1.destination),
        values:
          Enum.map(Enum.take(report_data.operational_reports.route_counts, 8), fn row ->
            row.total_routes
          end)
      },
      shipments_trend: weekly_shipments_trend(filtered_bookings)
    }
    |> Jason.encode!()
  end

  defp weekly_shipments_trend(filtered_bookings) do
    today = Date.utc_today()

    days =
      6..0//-1
      |> Enum.map(fn offset -> Date.add(today, -offset) end)

    grouped_counts =
      filtered_bookings
      |> Enum.group_by(fn booking -> datetime_to_date(booking.inserted_at) end)

    %{
      labels: Enum.map(days, &Calendar.strftime(&1, "%d %b")),
      values: Enum.map(days, fn day -> grouped_counts |> Map.get(day, []) |> length() end)
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

  defp decimal_to_float(%Decimal{} = value) do
    value
    |> Decimal.round(2)
    |> Decimal.to_float()
  end

  defp decimal_to_float(value) when is_integer(value), do: value * 1.0
  defp decimal_to_float(value) when is_float(value), do: Float.round(value, 2)
  defp decimal_to_float(_), do: 0.0

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

  defp normalize_tab(tab) when tab in @valid_tabs, do: tab
  defp normalize_tab(_), do: "summary"

  defp tab_link_class(active_tab, tab) do
    [
      "whitespace-nowrap px-1 py-4 text-sm font-bold uppercase tracking-widest transition-colors border-b-2",
      if(active_tab == tab,
        do: "border-red-600 text-red-600",
        else: "border-transparent text-zinc-400 hover:text-zinc-600 hover:border-zinc-200"
      )
    ]
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false
end
