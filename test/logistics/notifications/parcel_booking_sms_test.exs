defmodule Logistics.Notifications.ParcelBookingSMSTest do
  use ExUnit.Case, async: true

  alias Logistics.Notifications.ParcelBookingSMS

  test "formats local 07 number to +254 format" do
    assert {:ok, "+254724989025"} = ParcelBookingSMS.format_phone_number("0724989025")
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
end
