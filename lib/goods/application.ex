defmodule Goods.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GoodsWeb.Telemetry,
      Goods.Repo,
      {DNSCluster, query: Application.get_env(:goods, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Goods.PubSub},
      # Start a worker by calling: Goods.Worker.start_link(arg)
      # {Goods.Worker, arg},
      # Start to serve requests, typically the last entry
      GoodsWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :goods]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Goods.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GoodsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
