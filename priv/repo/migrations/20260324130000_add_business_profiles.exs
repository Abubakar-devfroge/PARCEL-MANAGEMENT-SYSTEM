defmodule Goods.Repo.Migrations.AddBusinessProfiles do
  use Ecto.Migration

  def change do
    create table(:business_profiles, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :company_name, :text, null: false
      add :business_type, :text, null: false
      add :country, :text, null: false
      add :primary_city, :text, null: false
      add :business_phone, :text, null: false
      add :brand_logo, :text

      add :user_id,
          references(:users,
            column: :id,
            type: :uuid,
            on_delete: :delete_all,
            name: "business_profiles_user_id_fkey"
          ),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:business_profiles, [:user_id], name: "business_profiles_unique_user_idx")
  end
end
