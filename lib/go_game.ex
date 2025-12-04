defmodule GoGame do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      GoGame.Repo,
      # Start the Telemetry supervisor
      GoGameWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: GoGame.PubSub},
      # Start the Endpoint (http/https)
      GoGameWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GoGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
