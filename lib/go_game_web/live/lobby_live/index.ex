defmodule GoGameWeb.LobbyLive.Index do
  use GoGameWeb, :live_view

  alias GoGameWeb.Presence
  alias GoGame.Games
  alias GoGame.Accounts

  @presence_topic "users:presence"

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Only track presence if the websocket is actually connected
    if connected?(socket) do
      GoGameWeb.Endpoint.subscribe(@presence_topic)
      # Subscribe to user-specific game invitations
      GoGameWeb.Endpoint.subscribe("user:#{user.id}:games")

      # Track the current user
      {:ok, _} =
        Presence.track(self(), @presence_topic, user.id, %{
          username: user.username,
          status: :online,
          user_id: user.id
        })
    end

    # Fetch the initial list of users and games
    {:ok,
     socket
     |> assign(:online_users, list_present_users())
     |> assign(:current_user_id, user.id)
     |> assign(:pending_games, list_user_games(user.id))}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: _diff}, socket) do
    # Update the list whenever someone joins or leaves
    {:noreply, assign(socket, :online_users, list_present_users())}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "game_invitation", payload: payload}, socket) do
    # Someone invited this user to a game
    {:noreply,
     socket
     |> put_flash(
       :info,
       "#{payload.inviter} invited you to a game! Please check the game list below."
     )
     |> assign(:pending_games, list_user_games(socket.assigns.current_user_id))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "game_updated", payload: payload}, socket) do
    # Refresh the games list
    updated_games = list_user_games(socket.assigns.current_user_id)

    # If a game was accepted (became in_progress), redirect to it
    if payload[:game_id] && payload[:accepted] do
      {:noreply,
       push_navigate(assign(socket, :pending_games, updated_games),
         to: ~p"/game/#{payload.game_id}"
       )}
    else
      {:noreply, assign(socket, :pending_games, updated_games)}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "game_refused", payload: payload}, socket) do
    # Refresh the games list (cancelled game will be filtered out)
    updated_games = list_user_games(socket.assigns.current_user_id)

    # Show notification to Player A
    refuser_name =
      if String.starts_with?(payload.refuser, "Guest_"), do: "Guest", else: payload.refuser

    {:noreply,
     socket
     |> put_flash(:error, "#{refuser_name} declined your game invitation")
     |> assign(:pending_games, updated_games)}
  end

  @impl true
  def handle_event("invite_player", %{"user-id" => user_id_str, "username" => _username}, socket) do
    current_user = socket.assigns.current_scope.user
    invited_user_id = String.to_integer(user_id_str)
    invited_user = Accounts.get_user!(invited_user_id)

    # Create a new game with status "pending" (waiting for Player B to accept)
    case Games.create_game(current_user, %{white_player_id: invited_user.id, status: "pending"}) do
      {:ok, game} ->
        # Notify the invited player via PubSub
        GoGameWeb.Endpoint.broadcast("user:#{invited_user.id}:games", "game_invitation", %{
          game_id: game.id,
          inviter: current_user.username
        })

        # Stay in lobby and show waiting message
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent, waiting for opponent to accept")
         |> assign(:pending_games, list_user_games(current_user.id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create game")}
    end
  end

  @impl true
  def handle_event("accept_invitation", %{"game-id" => game_id}, socket) do
    current_user = socket.assigns.current_scope.user
    game = Games.get_game!(game_id)

    # Accept the invitation by joining the game (sets status to "in_progress")
    case Games.join_game(game, current_user) do
      {:ok, _updated_game} ->
        # Notify the inviter that the game is accepted and redirect them too
        GoGameWeb.Endpoint.broadcast("user:#{game.black_player_id}:games", "game_updated", %{
          game_id: game_id,
          accepted: true
        })

        # Redirect to the game page
        {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to join game")}
    end
  end

  @impl true
  def handle_event("refuse_invitation", %{"game-id" => game_id}, socket) do
    current_user = socket.assigns.current_scope.user
    game = Games.get_game!(game_id)

    # Cancel the game
    case Games.cancel_game(game) do
      {:ok, _cancelled_game} ->
        # Notify the inviter that the invitation was refused
        GoGameWeb.Endpoint.broadcast("user:#{game.black_player_id}:games", "game_refused", %{
          refuser: current_user.username
        })

        {:noreply,
         socket
         |> put_flash(:info, "Game invitation declined")
         |> assign(:pending_games, list_user_games(current_user.id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to decline invitation")}
    end
  end

  # Convert the Presence map into a list for the UI
  defp list_present_users do
    Presence.list(@presence_topic)
    |> Enum.map(fn {_user_id, data} ->
      # data.metas is a list of open tabs. We just take the first one.
      hd(data.metas)
    end)
  end

  # List games for a user (pending and in-progress)
  defp list_user_games(user_id) do
    Games.list_user_games(user_id)
  end
end
