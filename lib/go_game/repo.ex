defmodule GoGame.Repo do
  use Ecto.Repo,
    otp_app: :go_game,
    adapter: Ecto.Adapters.Postgres
end
