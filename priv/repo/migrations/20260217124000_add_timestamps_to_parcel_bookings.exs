defmodule Goods.Repo.Migrations.AddTimestampsToParcelBookings do
  use Ecto.Migration

  def up do
    execute(
      "ALTER TABLE parcel_bookings ADD COLUMN IF NOT EXISTS inserted_at timestamp(6) without time zone NOT NULL DEFAULT NOW()"
    )

    execute(
      "ALTER TABLE parcel_bookings ADD COLUMN IF NOT EXISTS updated_at timestamp(6) without time zone NOT NULL DEFAULT NOW()"
    )
  end

  def down do
    execute("ALTER TABLE parcel_bookings DROP COLUMN IF EXISTS updated_at")
    execute("ALTER TABLE parcel_bookings DROP COLUMN IF EXISTS inserted_at")
  end
end
