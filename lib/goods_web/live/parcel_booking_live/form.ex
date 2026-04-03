defmodule GoodsWeb.ParcelBookingLive.Form do
  use GoodsWeb, :live_view

  require Logger

  alias GoodsWeb.ParcelBookingLive.FormRouting
  alias GoodsWeb.ParcelBookingLive.FormSteps

  @max_step 3

  @impl true
  def mount(params, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)

    routing_setup =
      FormRouting.build_routing_setup(
        FormRouting.get_business_profile(socket.assigns.current_user)
      )

    parcel_booking =
      case params["id"] do
        nil ->
          nil

        id ->
          Ash.get!(Logistics.ParcelBooking, id,
            actor: socket.assigns.current_user,
            tenant: socket.assigns.current_user.company_key
          )
      end

    action = if is_nil(parcel_booking), do: "New", else: "Edit"
    page_title = "#{action} Parcel Booking"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(:current_step, 1)
     |> assign(:return_step_after_fix, nil)
     |> assign(:routing_setup, routing_setup)
     |> assign(:origin_options, routing_setup.origin_options)
     |> assign(:parcel_booking, parcel_booking)
     |> assign(:page_title, page_title)
     |> assign_form()
     |> assign_destination_options_from_form()}
  end

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
    merged_params =
      FormSteps.merge_with_existing_params(socket.assigns.form, parcel_booking_params)

    normalized_params =
      FormRouting.normalize_booking_params(merged_params, socket.assigns.routing_setup)

    destination_options =
      FormRouting.destination_options_for(
        Map.get(normalized_params, "origin_office_id"),
        socket.assigns.routing_setup,
        Map.get(normalized_params, "destination_office_id")
      )

    validated_form = AshPhoenix.Form.validate(socket.assigns.form, normalized_params)

    {:noreply,
     socket
     |> assign(:destination_options, destination_options)
     |> assign(:form, validated_form)
     |> maybe_restore_step_after_fix(validated_form)}
  end

  @impl true
  def handle_event("save", %{"parcel_booking" => parcel_booking_params}, socket) do
    merged_params =
      FormSteps.merge_with_existing_params(socket.assigns.form, parcel_booking_params)

    normalized_params =
      FormRouting.normalize_booking_params(merged_params, socket.assigns.routing_setup)

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
        error_step =
          FormSteps.step_for_first_error(form, socket.assigns.current_step, normalized_params)

        {:noreply,
         socket
         |> assign(:form, form)
         |> assign(:current_step, error_step)
         |> assign(
           :return_step_after_fix,
           if(error_step != socket.assigns.current_step,
             do: socket.assigns.current_step,
             else: socket.assigns.return_step_after_fix
           )
         )}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{parcel_booking: parcel_booking}} = socket) do
    form =
      if parcel_booking do
        AshPhoenix.Form.for_update(parcel_booking, :update,
          as: "parcel_booking",
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_user.company_key
        )
      else
        AshPhoenix.Form.for_create(Logistics.ParcelBooking, :create,
          as: "parcel_booking",
          actor: socket.assigns.current_user,
          tenant: socket.assigns.current_user.company_key
        )
      end

    assign(socket, form: to_form(form))
  end

  defp assign_destination_options_from_form(socket) do
    selected_origin =
      FormRouting.form_value(socket.assigns.form, :origin_office_id) ||
        socket.assigns.routing_setup.base_office

    selected_destination =
      FormRouting.form_value(socket.assigns.form, :destination_office_id) ||
        FormRouting.form_value(socket.assigns.form, :destination)

    assign(
      socket,
      :destination_options,
      FormRouting.destination_options_for(
        selected_origin,
        socket.assigns.routing_setup,
        selected_destination
      )
    )
  end

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

  defp maybe_restore_step_after_fix(socket, form) do
    case socket.assigns.return_step_after_fix do
      nil ->
        socket

      step_to_resume ->
        if FormSteps.step_has_errors?(form, socket.assigns.current_step, true) do
          socket
        else
          socket
          |> assign(:current_step, step_to_resume)
          |> assign(:return_step_after_fix, nil)
        end
    end
  end
end
