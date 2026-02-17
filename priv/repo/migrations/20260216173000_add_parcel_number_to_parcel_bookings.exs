defmodule Goods.Repo.Migrations.AddParcelNumberToParcelBookings do
  use Ecto.Migration

  def change do
    alter table(:parcel_bookings) do
      add :parcel_number, :text
    end

    create unique_index(:parcel_bookings, [:parcel_number])
  end
end
