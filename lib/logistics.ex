defmodule Logistics do
  use Ash.Domain,
    otp_app: :goods

  resources do
    resource Logistics.ParcelBooking
  end
end
