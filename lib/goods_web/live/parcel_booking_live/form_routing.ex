defmodule GoodsWeb.ParcelBookingLive.FormRouting do
  require Ash.Query

  def get_business_profile(nil), do: nil

  def get_business_profile(current_user) do
    Goods.Accounts.BusinessProfile
    |> Ash.Query.filter(user_id == ^current_user.id)
    |> Ash.read_one(actor: current_user)
    |> case do
      {:ok, profile} -> profile
      {:error, _error} -> nil
    end
  end

  def build_routing_setup(profile) do
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

  def destination_options_for(origin, %{routes: routes}, selected_destination) do
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

  def normalize_booking_params(params, routing_setup) do
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

  def form_value(form, field) do
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
