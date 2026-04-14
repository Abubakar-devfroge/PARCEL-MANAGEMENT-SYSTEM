defmodule GoodsWeb.ParcelBookingLive.FormSteps do
  @max_step 3
  @step_fields %{
    1 => ~w(sender_name  sender_phone receiver_name  receiver_phone),
    2 => ~w(origin_office_id destination_office_id route_id destination),
    3 => ~w(parcel_type quantity price)
  }
  @required_fields %{
    1 => ~w(sender_name  sender_phone receiver_name receiver_phone),
    2 => ~w(origin_office_id destination_office_id),
    3 => ~w(parcel_type quantity price)
  }

  def step_has_errors?(form, step, only_current_step) when is_boolean(only_current_step) do
    extracted_error_fields =
      form
      |> extract_form_errors()
      |> Enum.map(&extract_error_field_name/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    step_fields = Map.fetch!(@step_fields, step)

    has_step_errors =
      Enum.any?(step_fields, &MapSet.member?(extracted_error_fields, &1))

    cond do
      has_step_errors ->
        true

      only_current_step ->
        false

      true ->
        @required_fields
        |> Map.fetch!(step)
        |> Enum.any?(fn field ->
          value =
            form
            |> field_value(form_field_atom(field))
            |> normalize_string()

          value == ""
        end)
    end
  end

  def step_for_first_error(form, fallback_step, params) do
    extracted_error_fields =
      form
      |> extract_form_errors()
      |> Enum.map(&extract_error_field_name/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    error_fields =
      if MapSet.size(extracted_error_fields) == 0 do
        params
        |> missing_required_fields()
        |> MapSet.new()
      else
        extracted_error_fields
      end

    Enum.find(1..@max_step, fallback_step, fn step ->
      @step_fields
      |> Map.fetch!(step)
      |> Enum.any?(&MapSet.member?(error_fields, &1))
    end)
  end

  def merge_with_existing_params(form, incoming_params) do
    Map.merge(existing_form_params(form), incoming_params || %{})
  end

  defp extract_form_errors(%Phoenix.HTML.Form{source: source}), do: extract_form_errors(source)
  defp extract_form_errors(%{errors: errors}) when is_list(errors), do: errors
  defp extract_form_errors(_), do: []

  defp extract_error_field_name({field, _}) when is_atom(field), do: Atom.to_string(field)
  defp extract_error_field_name({field, _}) when is_binary(field), do: field
  defp extract_error_field_name({field, _, _}) when is_atom(field), do: Atom.to_string(field)
  defp extract_error_field_name({field, _, _}) when is_binary(field), do: field
  defp extract_error_field_name(%{field: field}) when is_atom(field), do: Atom.to_string(field)
  defp extract_error_field_name(%{field: field}) when is_binary(field), do: field

  defp extract_error_field_name(%{path: path}) when is_list(path) do
    path
    |> Enum.reverse()
    |> Enum.find_value(fn
      field when is_atom(field) and field not in [:arguments, :attributes] ->
        Atom.to_string(field)

      field when is_binary(field) and field not in ["arguments", "attributes"] ->
        field

      _ ->
        nil
    end)
  end

  defp extract_error_field_name(_), do: nil

  defp missing_required_fields(nil), do: []

  defp missing_required_fields(params) when is_map(params) do
    Enum.reduce(1..@max_step, [], fn step, acc ->
      missing_for_step =
        @required_fields
        |> Map.fetch!(step)
        |> Enum.filter(fn field ->
          params
          |> Map.get(field, "")
          |> normalize_string()
          |> Kernel.==("")
        end)

      acc ++ missing_for_step
    end)
  end

  defp existing_form_params(%Phoenix.HTML.Form{params: params}) when is_map(params), do: params

  defp existing_form_params(%Phoenix.HTML.Form{source: %{params: params}}) when is_map(params),
    do: params

  defp existing_form_params(_), do: %{}

  defp form_field_atom(field_name) when is_binary(field_name),
    do: String.to_existing_atom(field_name)

  defp field_value(form, field_atom) do
    case form[field_atom] do
      nil -> nil
      %{value: value} -> value
      field_data -> Map.get(field_data, :value)
    end
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(value), do: value |> to_string() |> String.trim()
end
