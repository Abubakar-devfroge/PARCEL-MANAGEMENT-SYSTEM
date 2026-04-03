defmodule Goods.Repo.Migrations.AddCompanyScopingToBusinessProfiles do
  use Ecto.Migration

  def up do
    alter table(:business_profiles) do
      add_if_not_exists :company_key, :text
    end

    execute """
    UPDATE business_profiles AS bp
    SET company_key = COALESCE(
      NULLIF(lower(trim(u.company_key)), ''),
      NULLIF(lower(trim(bp.company_name)), '')
    )
    FROM users AS u
    WHERE u.id = bp.user_id
      AND (bp.company_key IS NULL OR trim(bp.company_key) = '');
    """

    create_if_not_exists index(:business_profiles, [:company_key])
  end

  def down do
    drop_if_exists index(:business_profiles, [:company_key])

    alter table(:business_profiles) do
      remove_if_exists :company_key
    end
  end
end
