defmodule Goods.Accounts.BusinessProfile.Changes.AssignCompanyBootstrapAdmin do
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, profile ->
      maybe_promote_first_company_admin(profile)
      {:ok, profile}
    end)
  end

  defp maybe_promote_first_company_admin(profile) do
    normalized_company = normalize_company_key(profile.company_key || profile.company_name)

    if normalized_company == "" do
      :ok
    else
      sync_user_company_key(profile.user_id, normalized_company)

      has_existing_admin? =
        Goods.Accounts.BusinessProfile
        |> Ash.Query.filter(user.role == :admin and id != ^profile.id)
        |> Ash.exists?(authorize?: false, action: :read, tenant: normalized_company)

      if has_existing_admin? do
        :ok
      else
        promote_user_to_admin(profile.user_id)
      end
    end
  end

  defp promote_user_to_admin(nil), do: :ok

  defp promote_user_to_admin(user_id) do
    user = Ash.get!(Goods.Accounts.User, user_id, authorize?: false, action: :read)

    user
    |> Ash.Changeset.for_update(:set_role_internal, %{target_role: :admin}, authorize?: false)
    |> Ash.update!(authorize?: false)

    :ok
  end

  defp sync_user_company_key(nil, _company_key), do: :ok

  defp sync_user_company_key(user_id, company_key) do
    user = Ash.get!(Goods.Accounts.User, user_id, authorize?: false, action: :read)

    user
    |> Ash.Changeset.for_update(
      :set_company_key_internal,
      %{target_company_key: company_key},
      authorize?: false
    )
    |> Ash.update!(authorize?: false)

    :ok
  end

  defp normalize_company_key(company_name) when is_binary(company_name) do
    company_name
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_company_key(_), do: ""
end
