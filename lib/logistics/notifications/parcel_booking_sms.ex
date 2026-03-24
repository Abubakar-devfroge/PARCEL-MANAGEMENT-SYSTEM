defmodule Logistics.Notifications.ParcelBookingSMS do
  require Logger

  @default_base_url "https://api.africastalking.com/version1/messaging"

  def send_booking_confirmation(parcel_booking) do
    sender_message =
      "Parcel booked successfully. Here is your parcel number: #{parcel_booking.parcel_number}."

    recipient_message =
      "#{sender_display_name(parcel_booking.sender_name)} has sent parcels to you. Here is parcel number: #{parcel_booking.parcel_number}."

    with :ok <- send_sms(parcel_booking.sender_phone, sender_message),
         :ok <- send_sms(parcel_booking.receiver_phone, recipient_message) do
      :ok
    end
  end

  def format_phone_number(phone_number), do: normalize_phone(phone_number)

  defp sender_display_name(name) when is_binary(name) do
    normalized = String.trim(name)
    if normalized == "", do: "The sender", else: normalized
  end

  defp sender_display_name(_), do: "The sender"

  defp send_sms(phone_number, message) do
    with {:ok, config} <- sms_config(),
         {:ok, to} <- format_phone_number(phone_number),
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
        Logger.warning(
          "Failed to call Africa's Talking SMS API for recipient #{to}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp handle_response(%Req.Response{status: status, body: body}) when status in 200..299 do
    case delivery_error(body) do
      nil ->
        Logger.info("Booking SMS sent successfully via Africa's Talking")
        :ok

      reason ->
        Logger.warning(
          "Africa's Talking SMS delivery failed: #{inspect(reason)} | provider_details=#{inspect(provider_error_details(body))}"
        )

        {:error, {:delivery_error, reason}}
    end
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    details = provider_error_details(body)
    provider_message = Map.get(details, :provider_message)

    if is_binary(provider_message) and provider_message != "" do
      Logger.warning("Africa's Talking provider message: #{provider_message}")
    end

    Logger.warning(
      "Africa's Talking SMS request failed with status #{status}: #{inspect(details)}"
    )

    {:error, {:http_error, status, details}}
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

  defp provider_error_details(%{"SMSMessageData" => %{} = sms_data}) do
    message = Map.get(sms_data, "Message")
    recipients = Map.get(sms_data, "Recipients", [])

    failed_recipients =
      recipients
      |> Enum.reject(&recipient_successful?/1)
      |> Enum.map(fn recipient ->
        %{
          number: Map.get(recipient, "number") || Map.get(recipient, "phoneNumber"),
          status: Map.get(recipient, "status"),
          status_code: Map.get(recipient, "statusCode"),
          cost: Map.get(recipient, "cost")
        }
      end)

    %{provider_message: message, failed_recipients: failed_recipients}
  end

  defp provider_error_details(body) when is_binary(body) do
    %{provider_message: String.trim(body)}
  end

  defp provider_error_details(body), do: %{raw_response: body}

  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end
