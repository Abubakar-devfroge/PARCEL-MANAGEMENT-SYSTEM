defmodule GoodsWeb.ParcelBookingLive.Index do
  use GoodsWeb, :live_view

  require Ash.Query

  @page_size 40

  @impl true
  def mount(_params, _session, socket) do
    pagination_mode = pagination_mode()

    {:ok,
     socket
     |> assign(:page_title, "Listing Parcel bookings")
     |> assign_new(:current_user, fn -> nil end)
     |> assign(:delete_parcel_id, nil)
     |> assign(:search_query, "")
     |> assign(:parcel_bookings_count, 0)
     |> assign(:filtered_parcel_bookings_count, 0)
     |> assign(:loading_more?, false)
     |> assign(:has_more?, true)
     |> assign(:next_cursor, nil)
     |> assign(:next_offset, 0)
     |> assign(:pagination_mode, pagination_mode)
     |> stream(:parcel_bookings, [])
     |> reset_and_load(refresh_total_count?: true)}
  end

  @impl true
  def handle_event("load-more", _params, %{assigns: %{loading_more?: true}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load-more", _params, %{assigns: %{has_more?: false}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    {:noreply, load_next_page(socket)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    normalized_query = query |> to_string() |> String.trim()

    {:noreply,
     socket
     |> assign(:search_query, normalized_query)
     |> reset_and_load()}
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
    parcel_booking =
      Ash.get!(Logistics.ParcelBooking, id,
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_user.company_key
      )

    Ash.destroy!(parcel_booking,
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_user.company_key
    )

    {:noreply,
     socket
     |> assign(:delete_parcel_id, nil)
     |> reset_and_load(refresh_total_count?: true)}
  end

  defp load_next_page(socket) do
    load_page(socket, reset?: false)
  end

  defp reset_and_load(socket, opts \\ []) do
    refresh_total_count? = Keyword.get(opts, :refresh_total_count?, false)

    socket
    |> assign(:loading_more?, false)
    |> assign(:has_more?, true)
    |> assign(:next_cursor, nil)
    |> assign(:next_offset, 0)
    |> assign(:filtered_parcel_bookings_count, 0)
    |> stream(:parcel_bookings, [], reset: true)
    |> load_page(reset?: true, refresh_total_count?: refresh_total_count?)
  end

  defp load_page(socket, opts) do
    reset? = Keyword.get(opts, :reset?, false)
    refresh_total_count? = Keyword.get(opts, :refresh_total_count?, false)

    socket = assign(socket, :loading_more?, true)
    page = fetch_page(socket, reset?, count?: reset?)
    records = page_records(page)

    socket
    |> stream(:parcel_bookings, records, reset: reset?)
    |> assign(:loading_more?, false)
    |> assign(:has_more?, page_more?(page))
    |> assign_next_page_state(page, records)
    |> maybe_assign_filtered_count(page, reset?)
    |> maybe_assign_total_count(page, reset?, refresh_total_count?)
  end

  defp fetch_page(socket, reset?, opts) do
    count? = Keyword.get(opts, :count?, false)

    query = parcel_booking_query(socket.assigns.search_query)
    page_opts = pagination_opts(socket, reset?, count?)

    Ash.read!(query,
      actor: socket.assigns.current_user,
      tenant: socket.assigns.current_user.company_key,
      page: page_opts
    )
  end

  defp pagination_opts(socket, reset?, count?) do
    base_opts =
      [limit: @page_size]
      |> maybe_put_count(count?)

    case socket.assigns.pagination_mode do
      :keyset ->
        case {reset?, socket.assigns.next_cursor} do
          {false, cursor} when is_binary(cursor) -> Keyword.put(base_opts, :after, cursor)
          _ -> base_opts
        end

      :offset ->
        offset = if reset?, do: 0, else: socket.assigns.next_offset
        Keyword.put(base_opts, :offset, offset)
    end
  end

  defp maybe_put_count(page_opts, true), do: Keyword.put(page_opts, :count, true)
  defp maybe_put_count(page_opts, false), do: page_opts

  defp assign_next_page_state(socket, page, records) do
    case socket.assigns.pagination_mode do
      :keyset ->
        next_cursor =
          if page_more?(page) do
            records
            |> List.last()
            |> keyset_for_record()
          else
            nil
          end

        assign(socket, :next_cursor, next_cursor)

      :offset ->
        assign(socket, :next_offset, socket.assigns.next_offset + length(records))
    end
  end

  defp maybe_assign_filtered_count(socket, page, true) do
    filtered_count = page_count(page) || length(page_records(page))
    assign(socket, :filtered_parcel_bookings_count, filtered_count)
  end

  defp maybe_assign_filtered_count(socket, _page, false), do: socket

  defp maybe_assign_total_count(
         %{assigns: %{search_query: ""}} = socket,
         page,
         true,
         _refresh_total_count?
       ) do
    total_count = page_count(page) || length(page_records(page))
    assign(socket, :parcel_bookings_count, total_count)
  end

  defp maybe_assign_total_count(socket, _page, _reset?, true) do
    assign(socket, :parcel_bookings_count, count_total_records(socket))
  end

  defp maybe_assign_total_count(socket, _page, _reset?, false), do: socket

  defp count_total_records(socket) do
    page =
      ""
      |> parcel_booking_query()
      |> Ash.read!(
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_user.company_key,
        page: [limit: 1, count: true]
      )

    page_count(page) || 0
  end

  defp parcel_booking_query(search_query) do
    Logistics.ParcelBooking
    |> Ash.Query.sort(inserted_at: :desc, id: :desc)
    |> maybe_filter_by_search(search_query)
  end

  defp maybe_filter_by_search(query, search_query) do
    normalized_query = search_query |> to_string() |> String.trim() |> String.downcase()

    if normalized_query == "" do
      query
    else
      Ash.Query.filter(
        query,
        contains(string_downcase(parcel_number), ^normalized_query) or
          contains(string_downcase(sender_name), ^normalized_query) or
          contains(string_downcase(sender_id), ^normalized_query) or
          contains(string_downcase(sender_phone), ^normalized_query) or
          contains(string_downcase(receiver_name), ^normalized_query) or
          contains(string_downcase(receiver_id), ^normalized_query) or
          contains(string_downcase(receiver_phone), ^normalized_query) or
          contains(string_downcase(parcel_type), ^normalized_query) or
          contains(string_downcase(destination), ^normalized_query)
      )
    end
  end

  defp pagination_mode do
    read_action = Ash.Resource.Info.action(Logistics.ParcelBooking, :read)

    if read_action && read_action.pagination && read_action.pagination.keyset? do
      :keyset
    else
      :offset
    end
  end

  defp page_records(%{results: records}) when is_list(records), do: records
  defp page_records(records) when is_list(records), do: records
  defp page_records(_), do: []

  defp page_count(%{count: count}) when is_integer(count), do: count
  defp page_count(_), do: nil

  defp page_more?(%{more?: more?}) when is_boolean(more?), do: more?
  defp page_more?(_), do: false

  defp keyset_for_record(nil), do: nil

  defp keyset_for_record(record),
    do: record |> Map.get(:__metadata__, %{}) |> Map.get(:keyset)
end
