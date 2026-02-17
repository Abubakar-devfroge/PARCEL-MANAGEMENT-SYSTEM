defmodule Goods.Accounts do
  use Ash.Domain, otp_app: :goods, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Goods.Accounts.Token
    resource Goods.Accounts.User
  end
end
