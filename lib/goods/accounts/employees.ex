defmodule Goods.Accounts.Employees do
  @moduledoc """
  Employee management service built on top of the `Goods.Accounts.User` resource.
  """

  require Ash.Query

  alias Goods.Accounts.EmployeeInviteMailer
  alias Goods.Accounts.InviteTokens
  alias Goods.Accounts.User

  def list(actor, search_query \\ "") do
    search = search_query |> to_string() |> String.trim() |> String.downcase()

    query =
      User
      |> Ash.Query.for_read(:employees, %{}, actor: actor)
      |> maybe_filter_by_search(search)

    Ash.read!(query, actor: actor)
  end

  def create_employee(actor, attrs) do
    {raw_token, token_hash, invite_sent_at} = InviteTokens.generate()

    params =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.put("invite_token", token_hash)
      |> Map.put("invite_sent_at", invite_sent_at)

    case Ash.create(User, params, action: :create_employee, actor: actor) do
      {:ok, user} ->
        case EmployeeInviteMailer.deliver_invite_email(user, raw_token) do
          :ok -> {:ok, user}
          {:error, reason} -> {:error, {:invite_email_failed, user, reason}}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def find_user_by_invite_token(raw_token) when is_binary(raw_token) do
    token_hash = InviteTokens.hash(raw_token)

    query =
      User
      |> Ash.Query.for_read(:get_by_invite_token, %{invite_token: token_hash})

    case Ash.read_one(query) do
      {:ok, nil} -> {:error, :invalid_token}
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, error}
    end
  end

  def find_user_by_invite_token(_), do: {:error, :invalid_token}

  def set_password_from_invite(raw_token, password, password_confirmation) do
    with {:ok, user} <- find_user_by_invite_token(raw_token),
         false <- InviteTokens.expired?(user.invite_sent_at),
         {:ok, _updated_user} <-
           Ash.update(user, %{password: password, password_confirmation: password_confirmation},
             action: :set_password_from_invite
           ) do
      :ok
    else
      true -> {:error, :expired_token}
      {:error, error} -> {:error, error}
    end
  end

  defp maybe_filter_by_search(query, ""), do: query

  defp maybe_filter_by_search(query, search) do
    Ash.Query.filter(
      query,
      contains(string_downcase(name), ^search) or
        contains(string_downcase(email), ^search)
    )
  end
end
