defmodule Goods.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Goods.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:goods, :token_signing_secret)
  end
end
