defmodule GoodsWeb.ParcelBookingLive.Index do
  use GoodsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    parcel_bookings = list_parcel_bookings(socket)

    {:ok,
     socket
     |> assign(:page_title, "Listing Parcel bookings")
     |> assign_new(:current_user, fn -> nil end)
     |> assign(:delete_parcel_id, nil)
     |> assign(:search_query, "")
     |> assign(:all_parcel_bookings, parcel_bookings)
     |> assign(:parcel_bookings_count, length(parcel_bookings))
     |> assign(:filtered_parcel_bookings_count, length(parcel_bookings))
     |> stream(:parcel_bookings, parcel_bookings)}
  end

  defp format_eat_datetime(nil), do: "—"

  defp format_eat_datetime(%DateTime{} = utc_datetime) do
    utc_datetime
    |> DateTime.add(3 * 60 * 60, :second)
    |> Calendar.strftime("%d %b %Y %H:%M")
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    parcel_bookings = list_parcel_bookings(socket)
    filtered_parcel_bookings = filter_bookings(parcel_bookings, query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:all_parcel_bookings, parcel_bookings)
     |> assign(:parcel_bookings_count, length(parcel_bookings))
     |> assign(:filtered_parcel_bookings_count, length(filtered_parcel_bookings))
     |> stream(:parcel_bookings, filtered_parcel_bookings, reset: true)}
  end

  @impl true
  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_parcel_id, id)}
  end

  @impl true
  def handle_event("close_delete_modal", _params, socket) do
    {:noreply, assign(socket, :delete_parcel_id, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    parcel_booking = Ash.get!(Logistics.ParcelBooking, id, actor: socket.assigns.current_user)
    Ash.destroy!(parcel_booking, actor: socket.assigns.current_user)

    all_parcel_bookings = list_parcel_bookings(socket)

    filtered_parcel_bookings = filter_bookings(all_parcel_bookings, socket.assigns.search_query)

    {:noreply,
     socket
     |> stream(:parcel_bookings, filtered_parcel_bookings, reset: true)
     |> assign(:delete_parcel_id, nil)
     |> assign(:all_parcel_bookings, all_parcel_bookings)
     |> assign(:parcel_bookings_count, length(all_parcel_bookings))
     |> assign(:filtered_parcel_bookings_count, length(filtered_parcel_bookings))}
  end

  defp list_parcel_bookings(socket) do
    Ash.read!(Logistics.ParcelBooking, actor: socket.assigns[:current_user])
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp filter_bookings(parcel_bookings, query) do
    normalized_query = query |> to_string() |> String.trim() |> String.downcase()

    if normalized_query == "" do
      parcel_bookings
    else
      query_tokens =
        normalized_query
        |> String.split(~r/\s+/, trim: true)

      Enum.filter(parcel_bookings, fn parcel_booking ->
        values = searchable_values(parcel_booking)

        Enum.all?(query_tokens, fn token ->
          compact_token = compact_search(token)

          Enum.any?(values, fn value ->
            compact_value = compact_search(value)

            String.contains?(value, token) ||
              (compact_token != "" &&
                 (String.contains?(compact_value, compact_token) || compact_value == compact_token))
          end)
        end)
      end)
    end
  end

  defp searchable_values(parcel_booking) do
    [
      parcel_booking.id,
      parcel_booking.parcel_number,
      parcel_booking.sender_name,
      parcel_booking.sender_id,
      parcel_booking.sender_phone,
      parcel_booking.receiver_name,
      parcel_booking.receiver_id,
      parcel_booking.receiver_phone,
      parcel_booking.parcel_type,
      parcel_booking.destination,
      format_eat_datetime(parcel_booking.inserted_at)
    ]
    |> Enum.map(&normalize_value/1)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value), do: value |> to_string() |> String.downcase()

  defp compact_search(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/u, "")
  end
end
