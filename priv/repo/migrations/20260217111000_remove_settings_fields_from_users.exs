defmodule Goods.Repo.Migrations.RemoveSettingsFieldsFromUsers do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE users DROP COLUMN IF EXISTS logo_url")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS avatar_url")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS business_address")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS business_phone")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS business_name")
  end

  def down do
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS business_name text")
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS business_phone text")
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS business_address text")
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url text")
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS logo_url text")
  end
end
