defmodule Logistics.Notifications.ParcelBookingSMSTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  alias Logistics.Notifications.ParcelBookingSMS

  setup do
    previous_config = Application.get_env(:goods, ParcelBookingSMS)

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:goods, ParcelBookingSMS)
      else
        Application.put_env(:goods, ParcelBookingSMS, previous_config)
      end
    end)

    :ok
  end

  test "formats local 07 number to +254 format" do
    assert {:ok, "+254724989025"} = ParcelBookingSMS.format_phone_number("0724989025")
  end

  test "formats 0726665174 to +254726665174" do
    assert {:ok, "+254726665174"} = ParcelBookingSMS.format_phone_number("0726665174")
  end

  test "formats 254-prefixed number to +254 format" do
    assert {:ok, "+254724989025"} = ParcelBookingSMS.format_phone_number("254724989025")
  end

  test "keeps +254 formatted number unchanged" do
    assert {:ok, "+254724989025"} = ParcelBookingSMS.format_phone_number("+254724989025")
  end

  test "formats short 7xxxxxxxx number to +254 format" do
    assert {:ok, "+254724989025"} = ParcelBookingSMS.format_phone_number("724989025")
  end

  test "removes spaces, dashes and parentheses before formatting" do
    assert {:ok, "+254724989025"} =
             ParcelBookingSMS.format_phone_number("(0724) 989-025")
  end

  test "returns error for blank or non-string input" do
    assert {:error, :invalid_phone_number} = ParcelBookingSMS.format_phone_number("   ")
    assert {:error, :invalid_phone_number} = ParcelBookingSMS.format_phone_number(nil)
  end

  test "logs SMS provider call failure details when request cannot be sent" do
    Application.put_env(:goods, ParcelBookingSMS,
      username: "sandbox",
      api_key: "test-key",
      from: nil,
      base_url: "http://127.0.0.1:1/version1/messaging"
    )

    booking = %{
      id: "booking-1",
      parcel_number: "NRB-ISIOLO-5149E",
      sender_name: "Abu",
      sender_phone: "0726665174",
      receiver_phone: "0726665174"
    }

    log =
      capture_log(fn ->
        assert {:error, {:sender_sms_failed, _reason}} =
                 ParcelBookingSMS.send_booking_confirmation(booking)
      end)

    assert log =~ "Failed to call Africa's Talking SMS API for recipient +254726665174"
    assert log =~ "Parcel booking SMS failed for sender 0726665174"
  end
end
