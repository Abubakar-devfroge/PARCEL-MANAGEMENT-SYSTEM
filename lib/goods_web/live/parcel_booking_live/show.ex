defmodule GoodsWeb.ParcelBookingLive.Show do
  use GoodsWeb, :live_view

  # @impl true
  # def render(assigns) do
  #   ~H"""
  #   <Layouts.app flash={@flash}>
  #     <.header>
  #       Parcel booking {@parcel_booking.id}
  #       <:subtitle>This is a parcel_booking record from your database.</:subtitle>

  #       <:actions>
  #         <.button navigate={~p"/parcel_bookings"}>
  #           <.icon name="hero-arrow-left" />
  #         </.button>
  #         <.button
  #           variant="primary"
  #           navigate={~p"/parcel_bookings/#{@parcel_booking}/edit?return_to=show"}
  #         >
  #           <.icon name="hero-pencil-square" /> Edit Parcel booking
  #         </.button>
  #       </:actions>
  #     </.header>

  #     <.list>
  #       <:item title="Id">{@parcel_booking.parcel_number}</:item>
  #       <:item title="Sender name">{@parcel_booking.sender_name}</:item>
  #       <:item title="Sender ID">{@parcel_booking.sender_id}</:item>
  #       <:item title="Sender phone">{@parcel_booking.sender_phone}</:item>
  #       <:item title="Receiver name">{@parcel_booking.receiver_name}</:item>
  #       <:item title="Receiver ID">{@parcel_booking.receiver_id}</:item>
  #       <:item title="Receiver phone">{@parcel_booking.receiver_phone}</:item>
  #       <:item title="Destination">{@parcel_booking.destination}</:item>
  #       <:item title="Parcel type">{@parcel_booking.parcel_type}</:item>
  #       <:item title="Quantity">{@parcel_booking.quantity}</:item>
  #       <:item title="Price">{@parcel_booking.price}</:item>
  #     </.list>
  #   </Layouts.app>
  #   """
  # end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)

    {:ok,
     socket
     |> assign(:page_title, "Show Parcel booking")
     |> assign(
       :parcel_booking,
       Ash.get!(Logistics.ParcelBooking, id,
         actor: socket.assigns.current_user,
         tenant: socket.assigns.current_user.company_key
       )
     )}
  end

  defp format_eat_datetime(nil), do: "—"

  defp format_eat_datetime(%DateTime{} = utc_datetime) do
    utc_datetime
    |> DateTime.add(3 * 60 * 60, :second)
    |> Calendar.strftime("%d %b %Y %H:%M")
  end
end
