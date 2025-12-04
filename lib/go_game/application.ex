defmodule GoGame.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GoGameWeb.Telemetry,
      GoGame.Repo,
      {DNSCluster, query: Application.get_env(:go_game, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GoGame.PubSub},
      GoGameWeb.Presence,
      {Finch, name: GoGame.Finch},
      GoGameWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GoGame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GoGameWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
