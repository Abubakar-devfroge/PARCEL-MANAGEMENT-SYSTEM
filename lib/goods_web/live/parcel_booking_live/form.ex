defmodule GoodsWeb.ParcelBookingLive.Form do
  use GoodsWeb, :live_view

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage parcel bookings in your database.</:subtitle>
      </.header>

      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <.form
          for={@form}
          id="parcel_booking-form"
          phx-change="validate"
          phx-submit="save"
        >
          <!-- Sender Details -->
          <.input
            field={@form[:sender_name]}
            type="text"
            label="Sender Name"
            placeholder="John Doe"
            minlength="3"
            maxlength="15"
            required
          />
          <.input
            field={@form[:sender_id]}
            type="text"
            label="Sender ID"
            placeholder="12345678"
            required
          />
          <.input
            field={@form[:sender_phone]}
            type="text"
            label="Sender Phone"
            placeholder="712345678"
            required
          />
          
    <!-- Receiver Details -->
          <.input
            field={@form[:receiver_name]}
            type="text"
            label="Receiver Name"
            placeholder="Jane Doe"
            minlength="3"
            maxlength="15"
            required
          />
          <.input
            field={@form[:receiver_id]}
            type="text"
            label="Receiver ID"
            placeholder="87654321"
          />
          <.input
            field={@form[:receiver_phone]}
            type="text"
            label="Receiver Phone"
            placeholder="712345678"
            required
          />
          
    <!-- Parcel Details -->
          <.input
            field={@form[:destination]}
            type="text"
            label="Destination"
            placeholder="Nairobi"
            required
          />
          <.input
            field={@form[:parcel_type]}
            type="text"
            label="Parcel Type"
            required
          />
          <.input
            field={@form[:quantity]}
            type="number"
            label="Quantity"
            min="1"
            required
          />
          <.input
            field={@form[:price]}
            type="number"
            label="Price"
            step="any"
            required
          />
          
    <!-- Buttons -->
          <div class="mt-6 flex gap-4">
            <.button phx-disable-with="Saving..." variant="primary">Book Parcel</.button>
            <.button navigate={return_path(@return_to, @parcel_booking)}>Cancel</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)

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
     |> assign(:parcel_booking, parcel_booking)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  # Return path helper
  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"parcel_booking" => parcel_booking_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, parcel_booking_params))}
  end

  @impl true
  def handle_event("save", %{"parcel_booking" => parcel_booking_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: parcel_booking_params) do
      {:ok, parcel_booking} ->
        notify_parent({:saved, parcel_booking})
        maybe_send_booking_sms(socket.assigns.form.source.type, parcel_booking)

        socket =
          socket
          |> put_flash(:info, "Parcel booking #{socket.assigns.form.source.type}d successfully")
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

  # Return path helper
  defp return_path("index", _parcel_booking), do: ~p"/parcel_bookings"
  defp return_path("show", parcel_booking), do: ~p"/parcel_bookings/#{parcel_booking.id}"

  defp maybe_send_booking_sms(:create, parcel_booking) do
    Task.start(fn ->
      case Logistics.Notifications.ParcelBookingSMS.send_booking_confirmation(parcel_booking) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to send parcel booking SMS notification for booking #{parcel_booking.id} (#{parcel_booking.parcel_number}): #{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  defp maybe_send_booking_sms(_action, _parcel_booking), do: :ok
end
