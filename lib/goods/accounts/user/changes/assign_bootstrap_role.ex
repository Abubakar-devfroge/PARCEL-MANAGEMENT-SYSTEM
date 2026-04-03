defmodule Goods.Accounts.User.Changes.AssignBootstrapRole do
  use Ash.Resource.Change

  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    role = Changeset.get_attribute(changeset, :role)

    case role do
      nil ->
        Changeset.change_attribute(changeset, :role, :client)

      _ ->
        changeset
    end
  end
end
