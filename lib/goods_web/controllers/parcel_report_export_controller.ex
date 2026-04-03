defmodule GoodsWeb.ParcelReportExportController do
  use GoodsWeb, :controller

  def export(conn, params) do
    if admin?(conn.assigns[:current_user]) do
      report = Map.get(params, "report", "custom")
      format = Map.get(params, "format", "csv")
      filters = normalize_filters(Map.get(params, "filters", %{}))

      parcel_bookings =
        Ash.read!(Logistics.ParcelBooking,
          actor: conn.assigns[:current_user],
          tenant: conn.assigns[:current_user].company_key
        )
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      filtered_bookings = apply_filters(parcel_bookings, filters)
      report_data = build_report_data(filtered_bookings)

      {headers, rows} =
        export_rows(report, %{filtered_bookings: filtered_bookings, report_data: report_data})

      case {headers, rows} do
        {[], []} ->
          conn
          |> put_flash(:error, "No data available for export")
          |> redirect(to: ~p"/parcel_reports")

        _ ->
          delimiter = if format == "excel", do: "\t", else: ","
          extension = if format == "excel", do: "xls", else: "csv"

          content = delimited_content(headers, rows, delimiter)

          filename =
            ["parcel_reports", report, Date.utc_today() |> Date.to_iso8601()]
            |> Enum.join("_")
            |> Kernel.<>("." <> extension)

          content_type =
            if format == "excel",
              do: "application/vnd.ms-excel; charset=utf-8",
              else: "text/csv; charset=utf-8"

          conn
          |> put_resp_content_type(content_type)
          |> put_resp_header("content-disposition", "attachment; filename=#{filename}")
          |> send_resp(200, content)
      end
    else
      conn
      |> put_flash(:error, "Only admins can access reports")
      |> redirect(to: ~p"/dash")
    end
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

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
  defp optional_date(value), do: Date.from_iso8601(value)

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
      customer_reports: %{top_customers: top_customers},
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

  defp export_rows("activity", assigns) do
    activity = assigns.report_data.parcel_activity

    headers = ["metric", "value"]

    rows = [
      ["Total Shipments", activity.total_shipments],
      ["Daily Shipments", activity.daily_shipments],
      ["Weekly Shipments", activity.weekly_shipments],
      ["Monthly Shipments", activity.monthly_shipments],
      ["Cancelled Shipments", activity.cancelled_shipments],
      ["Returned Shipments", activity.returned_shipments]
    ]

    {headers, rows}
  end

  defp export_rows("customers", assigns) do
    headers = ["sender_name", "sender_phone", "total_shipments", "total_revenue"]

    rows =
      Enum.map(assigns.report_data.customer_reports.top_customers, fn row ->
        [
          row.sender_name,
          row.sender_phone,
          row.total_shipments,
          decimal_to_money(row.total_revenue)
        ]
      end)

    {headers, rows}
  end

  defp export_rows("financial", assigns) do
    headers = ["group", "name", "shipments", "revenue"]

    by_type_rows =
      Enum.map(assigns.report_data.financial_reports.revenue_by_type, fn row ->
        ["Parcel Type", row.parcel_type, row.shipments, decimal_to_money(row.revenue)]
      end)

    by_location_rows =
      Enum.map(assigns.report_data.financial_reports.revenue_by_location, fn row ->
        ["Destination", row.destination, row.shipments, decimal_to_money(row.revenue)]
      end)

    pending_row =
      [
        [
          "Pending Payments",
          "All filtered bookings",
          assigns.report_data.financial_reports.pending_payments_count,
          decimal_to_money(assigns.report_data.financial_reports.pending_payments_amount)
        ]
      ]

    {headers, by_type_rows ++ by_location_rows ++ pending_row}
  end

  defp export_rows("operations", assigns) do
    headers = ["metric", "value", "extra"]

    avg_row = [
      [
        "Average Parcel Volume",
        assigns.report_data.operational_reports.average_volume,
        "Units/booking"
      ]
    ]

    employee_rows =
      Enum.map(assigns.report_data.operational_reports.employee_handling, fn row ->
        ["Employee Handling", row.employee, row.total_shipments]
      end)

    route_rows =
      Enum.map(assigns.report_data.operational_reports.route_counts, fn row ->
        ["Route Count", row.destination, row.total_routes]
      end)

    {headers, avg_row ++ employee_rows ++ route_rows}
  end

  defp export_rows("custom", assigns) do
    headers = [
      "parcel_number",
      "sender",
      "sender_phone",
      "receiver",
      "receiver_phone",
      "destination",
      "parcel_type",
      "quantity",
      "price",
      "booked_at"
    ]

    rows =
      Enum.map(assigns.filtered_bookings, fn booking ->
        [
          booking.parcel_number,
          booking.sender_name,
          booking.sender_phone,
          booking.receiver_name,
          booking.receiver_phone,
          booking.destination,
          booking.parcel_type,
          booking.quantity,
          decimal_to_money(booking.price),
          format_eat_datetime(booking.inserted_at)
        ]
      end)

    {headers, rows}
  end

  defp export_rows(_, _assigns), do: {[], []}

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

  defp delimited_content(headers, rows, delimiter) do
    ([headers] ++ rows)
    |> Enum.map(fn row -> Enum.map_join(row, delimiter, &escape_field(&1, delimiter)) end)
    |> Enum.join("\n")
  end

  defp escape_field(value, delimiter) do
    string_value = to_string(value || "")

    if String.contains?(string_value, [delimiter, "\n", "\""]) do
      "\"" <> String.replace(string_value, "\"", "\"\"") <> "\""
    else
      string_value
    end
  end
end
