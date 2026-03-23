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
    username = config |> Keyword.get(:username) |> normalize_config_value()
    api_key = config |> Keyword.get(:api_key) |> normalize_config_value()
    from = config |> Keyword.get(:from) |> normalize_config_value()

    base_url =
      config
      |> Keyword.get(:base_url, @default_base_url)
      |> normalize_config_value()

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

  defp handle_response(%Req.Response{status: status, body: body}) when status in 200..299 do
    case delivery_error(body) do
      nil ->
        Logger.info("Booking SMS sent successfully via Africa's Talking")
        :ok

      reason ->
        Logger.warning("Africa's Talking SMS delivery failed: #{inspect(reason)}")
        {:error, {:delivery_error, reason}}
    end
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

  defp normalize_config_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_config_value(value), do: value

  defp delivery_error(%{"SMSMessageData" => %{"Message" => message, "Recipients" => recipients}})
       when is_binary(message) and is_list(recipients) do
    cond do
      String.contains?(message, "InvalidSenderId") ->
        :invalid_sender_id

      recipients == [] ->
        {:no_recipients, message}

      true ->
        failed_recipients = Enum.reject(recipients, &recipient_successful?/1)

        if failed_recipients == [] do
          nil
        else
          {:recipient_failures, failed_recipients}
        end
    end
  end

  defp delivery_error(_), do: nil

  defp recipient_successful?(%{"status" => status}) when is_binary(status) do
    String.contains?(status, "Success") or String.contains?(status, "Queued")
  end

  defp recipient_successful?(_), do: false

  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end
