defmodule Goods.Repo.Migrations.AddCompanyScopingToUsersAndParcelBookings do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists :company_key, :text
    end

    alter table(:parcel_bookings) do
      add_if_not_exists :company_key, :text
    end

    execute("""
    UPDATE users AS u
    SET company_key = lower(trim(bp.company_name))
    FROM business_profiles AS bp
    WHERE bp.user_id = u.id
      AND bp.company_name IS NOT NULL
      AND trim(bp.company_name) <> ''
      AND (u.company_key IS NULL OR trim(u.company_key) = '');
    """)

    create_if_not_exists index(:users, [:company_key])
    create_if_not_exists index(:parcel_bookings, [:company_key, :inserted_at])
  end

  def down do
    drop_if_exists index(:parcel_bookings, [:company_key, :inserted_at])
    drop_if_exists index(:users, [:company_key])

    alter table(:parcel_bookings) do
      remove_if_exists :company_key
    end

    alter table(:users) do
      remove_if_exists :company_key
    end
  end
end
