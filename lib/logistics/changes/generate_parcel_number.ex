defmodule Logistics.Changes.GenerateParcelNumber do
  use Ash.Resource.Change

  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    case Changeset.get_attribute(changeset, :parcel_number) do
      value when is_binary(value) and value != "" ->
        changeset

      _ ->
        destination =
          Changeset.get_attribute(changeset, :destination_office_id) ||
            Changeset.get_attribute(changeset, :destination) || "UNKNOWN"

        dest_code = sanitize_destination(destination)
        random_code = random_parcel_suffix()

        parcel_number = "NRB-#{dest_code}-#{random_code}"

        Changeset.change_attribute(changeset, :parcel_number, parcel_number)
    end
  end

  defp sanitize_destination(destination) do
    destination
    |> String.upcase()
    |> String.replace(~r/\s+/, "")
    |> String.replace(~r/[^A-Z0-9]/, "")
    |> case do
      "" -> "UNKNOWN"
      value -> value
    end
  end

  defp random_parcel_suffix do
    :crypto.strong_rand_bytes(5)
    |> Base.encode16(case: :upper)
    |> String.slice(0, 5)
  end
end
