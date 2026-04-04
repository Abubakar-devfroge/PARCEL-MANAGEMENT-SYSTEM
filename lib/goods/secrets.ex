defmodule Goods.Secrets do
  use AshAuthentication.Secret

  # Matches the path Ash uses to find the signing secret
  def secret_for([:authentication, :tokens, :signing_secret], Goods.Accounts.User, _opts) do
    case System.get_env("TOKEN_SIGNING_SECRET") do
      nil -> :error
      secret -> {:ok, secret}
    end
  end

  # Catch-all to prevent crashes if Ash looks for other secrets
  def secret_for(_path, _resource, _opts), do: :error
end
