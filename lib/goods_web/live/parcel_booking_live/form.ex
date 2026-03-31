defmodule GoodsWeb.ParcelBookingLive.Form do
  use GoodsWeb, :live_view

  require Ash.Query
  require Logger

  @max_step 3



  @impl true
  def mount(params, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)
    routing_setup = build_routing_setup(get_business_profile(socket.assigns.current_user))

    parcel_booking =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Logistics.ParcelBooking, id, actor: socket.assigns.current_user)
      end

    action = if is_nil(parcel_booking), do: "New", else: "Edit"
    page_title = "#{action} Parcel Booking"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
      |> assign(:current_step, 1)
     |> assign(:routing_setup, routing_setup)
     |> assign(:origin_options, routing_setup.origin_options)
     |> assign(:parcel_booking, parcel_booking)
     |> assign(:page_title, page_title)
     |> assign_form()
     |> assign_destination_options_from_form()}
  end

  # Return path helper
  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :current_step, min(socket.assigns.current_step + 1, @max_step))}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :current_step, max(socket.assigns.current_step - 1, 1))}
  end

  @impl true
  def handle_event("validate", %{"parcel_booking" => parcel_booking_params}, socket) do
    normalized_params =
      normalize_booking_params(parcel_booking_params, socket.assigns.routing_setup)

    destination_options =
      destination_options_for(
        Map.get(normalized_params, "origin_office_id"),
        socket.assigns.routing_setup,
        Map.get(normalized_params, "destination_office_id")
      )

    {:noreply,
     socket
     |> assign(:destination_options, destination_options)
     |> assign(:form, AshPhoenix.Form.validate(socket.assigns.form, normalized_params))}
  end

  @impl true
  def handle_event("save", %{"parcel_booking" => parcel_booking_params}, socket) do
    normalized_params =
      normalize_booking_params(parcel_booking_params, socket.assigns.routing_setup)

    case AshPhoenix.Form.submit(socket.assigns.form, params: normalized_params) do
      {:ok, parcel_booking} ->
        notify_parent({:saved, parcel_booking})
        sms_result = maybe_send_booking_sms(socket.assigns.form.source.type, parcel_booking)

        socket =
          socket
          |> put_flash(:info, "Parcel booking #{socket.assigns.form.source.type}d successfully")
          |> maybe_put_sms_failure_flash(sms_result)
          |> push_navigate(to: return_path(socket.assigns.return_to, parcel_booking))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  # Notify parent (optional)
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  # Assign form (create or update)
  defp assign_form(%{assigns: %{parcel_booking: parcel_booking}} = socket) do
    form =
      if parcel_booking do
        AshPhoenix.Form.for_update(parcel_booking, :update,
          as: "parcel_booking",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Logistics.ParcelBooking, :create,
          as: "parcel_booking",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp assign_destination_options_from_form(socket) do
    selected_origin =
      form_value(socket.assigns.form, :origin_office_id) ||
        socket.assigns.routing_setup.base_office

    selected_destination =
      form_value(socket.assigns.form, :destination_office_id) ||
        form_value(socket.assigns.form, :destination)

    assign(
      socket,
      :destination_options,
      destination_options_for(selected_origin, socket.assigns.routing_setup, selected_destination)
    )
  end

  # Return path helper
  defp return_path("index", _parcel_booking), do: ~p"/parcel_bookings"
  defp return_path("show", parcel_booking), do: ~p"/parcel_bookings/#{parcel_booking.id}"

  defp maybe_send_booking_sms(:create, parcel_booking) do
    try do
      case Logistics.Notifications.ParcelBookingSMS.send_booking_confirmation(parcel_booking) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to send parcel booking SMS notification for booking #{parcel_booking.id} (#{parcel_booking.parcel_number}): #{inspect(reason)}"
          )

          {:error, reason}
      end
    rescue
      error ->
        Logger.error(
          "SMS notification call crashed for booking #{parcel_booking.id} (#{parcel_booking.parcel_number}): #{Exception.format(:error, error, __STACKTRACE__)}"
        )

        {:error, :sms_crashed}
    end
  end

  defp maybe_send_booking_sms(_action, _parcel_booking), do: :ok

  defp maybe_put_sms_failure_flash(socket, :ok), do: socket

  defp maybe_put_sms_failure_flash(socket, {:error, _reason}) do
    put_flash(
      socket,
      :error,
      "Parcel was booked, but SMS notification failed. Please check your Africa's Talking settings and server logs."
    )
  end

  defp get_business_profile(nil), do: nil

  defp get_business_profile(current_user) do
    Goods.Accounts.BusinessProfile
    |> Ash.Query.filter(user_id == ^current_user.id)
    |> Ash.read_one(actor: current_user)
    |> case do
      {:ok, profile} -> profile
      {:error, _error} -> nil
    end
  end

  defp build_routing_setup(profile) do
    base_office =
      profile
      |> value_or_nil(:base_office)
      |> fallback(value_or_nil(profile, :primary_city))
      |> fallback("Base Office")

    branch_offices = parse_lines(value_or_nil(profile, :branch_offices))
    delivery_destinations = parse_lines(value_or_nil(profile, :delivery_destinations))
    transfer_points = parse_lines(value_or_nil(profile, :transfer_points))

    offices =
      [base_office | branch_offices ++ delivery_destinations ++ transfer_points]
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    configured_routes = parse_routes(value_or_nil(profile, :valid_routes))

    routes =
      case configured_routes do
        [] -> default_routes(base_office, offices)
        entries -> entries
      end

    origin_options =
      routes
      |> Enum.map(& &1.origin)
      |> Enum.uniq()
      |> Enum.map(&{&1, &1})

    %{
      base_office: base_office,
      routes: routes,
      origin_options: origin_options
    }
  end

  defp destination_options_for(origin, %{routes: routes}, selected_destination) do
    normalized_origin = normalize_string(origin)

    base_options =
      routes
      |> Enum.filter(fn route -> normalize_string(route.origin) == normalized_origin end)
      |> Enum.map(& &1.destination)
      |> Enum.uniq()

    options =
      case normalize_string(selected_destination) do
        "" ->
          base_options

        normalized_destination ->
          if Enum.any?(base_options, fn option ->
               normalize_string(option) == normalized_destination
             end) do
            base_options
          else
            [selected_destination | base_options]
          end
      end

    Enum.map(options, &{&1, &1})
  end

  defp normalize_booking_params(params, routing_setup) do
    origin =
      params
      |> Map.get("origin_office_id", routing_setup.base_office)
      |> normalize_string()
      |> fallback(routing_setup.base_office)

    destination =
      params
      |> Map.get("destination_office_id", "")
      |> normalize_string()

    route = find_route(routing_setup.routes, origin, destination)

    route_id =
      case route do
        nil -> route_identifier(origin, destination)
        valid_route -> valid_route.id
      end

    params
    |> Map.put("origin_office_id", origin)
    |> Map.put("destination_office_id", destination)
    |> Map.put("route_id", route_id)
    |> Map.put("destination", destination)
  end

  defp find_route(routes, origin, destination) do
    normalized_origin = normalize_string(origin)
    normalized_destination = normalize_string(destination)

    Enum.find(routes, fn route ->
      normalize_string(route.origin) == normalized_origin and
        normalize_string(route.destination) == normalized_destination
    end)
  end

  defp parse_routes(nil), do: []

  defp parse_routes(value) do
    value
    |> parse_lines()
    |> Enum.reduce([], fn line, acc ->
      case String.split(line, ~r/\s*(?:->|=>)\s*/, parts: 2) do
        [origin, destination] ->
          normalized_origin = normalize_string(origin)
          normalized_destination = normalize_string(destination)

          if normalized_origin == "" or normalized_destination == "" or
               normalized_origin == normalized_destination do
            acc
          else
            route = %{
              id: route_identifier(normalized_origin, normalized_destination),
              origin: normalized_origin,
              destination: normalized_destination
            }

            [route | acc]
          end

        _ ->
          acc
      end
    end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.reverse()
  end

  defp default_routes(base_office, offices) do
    offices
    |> Enum.reject(&(normalize_string(&1) == normalize_string(base_office)))
    |> Enum.map(fn destination ->
      %{
        id: route_identifier(base_office, destination),
        origin: base_office,
        destination: destination
      }
    end)
  end

  defp parse_lines(nil), do: []

  defp parse_lines(value) do
    value
    |> to_string()
    |> String.split(~r/[\n,]/, trim: true)
    |> Enum.map(&normalize_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp form_value(form, field) do
    case form[field] do
      nil ->
        nil

      field_data ->
        field_data
        |> Map.get(:value)
        |> case do
          nil ->
            nil

          value when is_binary(value) ->
            normalized = normalize_string(value)
            if normalized == "", do: nil, else: normalized

          value ->
            value
        end
    end
  end

  defp route_identifier(origin, destination) do
    "#{normalize_string(origin)}__#{normalize_string(destination)}"
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(value), do: value |> to_string() |> String.trim()

  defp value_or_nil(nil, _field), do: nil

  defp value_or_nil(struct, field) do
    struct
    |> Map.get(field)
    |> normalize_string()
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp fallback(nil, default), do: default
  defp fallback("", default), do: default
  defp fallback(value, _default), do: value
end
