defmodule GoGameWeb.Presence do
  use Phoenix.Presence,
    otp_app: :go_game,
    pubsub_server: GoGame.PubSub
end
