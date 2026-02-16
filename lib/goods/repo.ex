defmodule Goods.Repo do
  use Ecto.Repo,
    otp_app: :goods,
    adapter: Ecto.Adapters.Postgres
end
