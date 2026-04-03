defmodule Goods.Repo.Migrations.AddEmployeeInviteIndexes do
  use Ecto.Migration

  def up do
    create_if_not_exists index(:users, [:role])

    create_if_not_exists unique_index(:users, [:invite_token],
                           where: "invite_token IS NOT NULL",
                           name: "users_unique_invite_token_index"
                         )
  end

  def down do
    drop_if_exists unique_index(:users, [:invite_token], name: "users_unique_invite_token_index")
    drop_if_exists index(:users, [:role])
  end
end
