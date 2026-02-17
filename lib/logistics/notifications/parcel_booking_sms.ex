defmodule Logistics.Notifications.ParcelBookingSMS do
  require Logger

  @default_base_url "https://api.africastalking.com/version1/messaging"

  def send_booking_confirmation(parcel_booking) do
    message = "Parcel booked successfully. Parcel number: #{parcel_booking.parcel_number}."

    send_sms(parcel_booking.sender_phone, message)
  end

  defp send_sms(phone_number, message) do
    with {:ok, config} <- sms_config(),
         {:ok, to} <- normalize_phone(phone_number),
         {:ok, response} <- send_request(config, to, message),
         :ok <- handle_response(response) do
      :ok
    end
  end

  defp sms_config do
    config = Application.get_env(:goods, __MODULE__, [])
    username = Keyword.get(config, :username)
    api_key = Keyword.get(config, :api_key)
    from = Keyword.get(config, :from)
    base_url = Keyword.get(config, :base_url, @default_base_url)

    if blank?(username) or blank?(api_key) do
      {:error, :missing_credentials}
    else
      {:ok, %{username: username, api_key: api_key, from: from, base_url: base_url}}
    end
  end

  defp send_request(config, to, message) do
    form_body =
      [
        username: config.username,
        to: to,
        message: message,
        from: config.from
      ]
      |> Enum.reject(fn {_key, value} -> blank?(value) end)

    case Req.post(config.base_url,
           headers: [
             {"accept", "application/json"},
             {"apiKey", config.api_key}
           ],
           form: form_body,
           receive_timeout: 10_000
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Logger.warning("Failed to call Africa's Talking SMS API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_response(%Req.Response{status: status} = response) when status in 200..299 do
    Logger.info("Booking SMS sent successfully via Africa's Talking")
    _ = response
    :ok
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    Logger.warning("Africa's Talking SMS request failed with status #{status}: #{inspect(body)}")

    {:error, {:http_error, status}}
  end

  defp normalize_phone(phone_number) when is_binary(phone_number) do
    cleaned =
      phone_number
      |> String.trim()
      |> String.replace(~r/[\s\-\(\)]/, "")

    formatted =
      cond do
        String.starts_with?(cleaned, "+") ->
          cleaned

        String.starts_with?(cleaned, "254") ->
          "+#{cleaned}"

        String.starts_with?(cleaned, "0") and String.length(cleaned) == 10 ->
          "+254" <> String.slice(cleaned, 1, 9)

        String.starts_with?(cleaned, "7") and String.length(cleaned) == 9 ->
          "+254" <> cleaned

        true ->
          cleaned
      end

    if blank?(formatted), do: {:error, :invalid_phone_number}, else: {:ok, formatted}
  end

  defp normalize_phone(_), do: {:error, :invalid_phone_number}

  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end
