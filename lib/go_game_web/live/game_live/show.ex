defmodule GoGameWeb.GameLive.Show do
  use GoGameWeb, :live_view

  alias GoGame.Gameplay.Rules
  alias GoGame.Games
  alias GoGameWeb.Components.BoardRenderer

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    db_game = Games.get_game!(game_id)

    # Subscribe to game-specific updates
    if connected?(socket) do
      GoGameWeb.Endpoint.subscribe("game:#{game_id}")
    end

    # Load game state from database or start a new game
    rules_game =
      if map_size(db_game.game_state) == 0 do
        Rules.new()
      else
        Games.deserialize_game_state(db_game.game_state)
      end

    # Determine what color the current user is playing
    current_player_color =
      cond do
        current_user.id == db_game.black_player_id -> :black
        current_user.id == db_game.white_player_id -> :white
        true -> nil
      end

    # Start the clock ticker only if game is in progress
    if connected?(socket) and db_game.status == "in_progress" do
      schedule_tick()
    end

    {:ok,
     assign(socket,
       game: rules_game,
       db_game: db_game,
       current_player_color: current_player_color,
       black_player_name:
         if(String.starts_with?(db_game.black_player.username, "Guest_"),
           do: "Guest",
           else: db_game.black_player.username
         ),
       white_player_name:
         if(String.starts_with?(db_game.white_player.username, "Guest_"),
           do: "Guest",
           else: db_game.white_player.username
         ),
       game_id: game_id
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f3ead7] flex flex-col items-center justify-center py-2">
      <!-- Center everything and constrain to board width -->
      <div class="flex flex-col items-center w-full px-2">
        
    <!-- Game Info Header -->
        <div class="w-full max-w-2xl flex justify-between items-center mb-4 font-serif text-[#5e4b35]">
          <!-- Black Player Info -->
          <div class={"flex flex-col items-center p-2 rounded-lg border-2 transition-all duration-300 " <>
            if(@game.turn == :black && !@game.game_over, do: "border-[#dcb35c] bg-white shadow-lg scale-105", else: "border-transparent opacity-70")}>
            <div class="w-6 h-6 sm:w-8 sm:h-8 rounded-full bg-gradient-to-br from-gray-700 to-black shadow-md mb-1">
            </div>
            <span class="font-bold text-sm sm:text-base">{@black_player_name}</span>
            <span class="text-xs text-gray-500">Black</span>
            <div class={"mt-1 text-base sm:text-lg font-mono font-bold px-2 py-1 rounded " <>
              if(@game.turn == :black && !@game.game_over, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-600")}>
              {format_time(@game.black_time)}
            </div>
          </div>
          
    <!-- VS / Turn Indicator -->
          <div class="text-xl sm:text-2xl font-bold opacity-50">VS</div>
          
    <!-- White Player Info -->
          <div class={"flex flex-col items-center p-2 rounded-lg border-2 transition-all duration-300 " <>
            if(@game.turn == :white && !@game.game_over, do: "border-[#dcb35c] bg-white shadow-lg scale-105", else: "border-transparent opacity-70")}>
            <div class="w-6 h-6 sm:w-8 sm:h-8 rounded-full bg-gradient-to-br from-white to-gray-200 shadow-md border border-gray-300 mb-1">
            </div>
            <span class="font-bold text-sm sm:text-base">{@white_player_name}</span>
            <span class="text-xs text-gray-500">White</span>
            <div class={"mt-1 text-base sm:text-lg font-mono font-bold px-2 py-1 rounded " <>
              if(@game.turn == :white && !@game.game_over, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-600")}>
              {format_time(@game.white_time)}
            </div>
          </div>
        </div>
        
    <!-- The Board Component -->
        <div class="mb-8 w-full max-w-2xl">
          <BoardRenderer.board
            board={@game.board}
            interactive={@db_game.status == "in_progress" && !@game.game_over}
          />
        </div>
        
    <!-- Count Request Banner -->
        <%= if @game.count_requested_by && @game.count_requested_by != @current_player_color do %>
          <div class="w-full max-w-2xl mb-4 bg-[#dcb35c] border-2 border-[#cda24b] rounded-lg p-4 shadow-lg">
            <div class="text-center mb-3">
              <p class="text-lg font-serif font-semibold text-[#5e4b35]">
                {if @game.count_requested_by == :black, do: "Black", else: "White"} requested to count territory. Accept?
              </p>
              <p class="text-sm font-serif text-[#8b7355] mt-1">
                Accepting will calculate both players' scores and end the game
              </p>
            </div>
            <div class="flex justify-center gap-4">
              <button
                phx-click="accept_count"
                class="px-6 py-2 text-lg font-serif text-white bg-green-600 hover:bg-green-700 rounded-lg shadow-md transition-all"
              >
                Accept
              </button>
              <button
                phx-click="reject_count"
                class="px-6 py-2 text-lg font-serif text-white bg-red-600 hover:bg-red-700 rounded-lg shadow-md transition-all"
              >
                Decline
              </button>
            </div>
          </div>
        <% end %>
        
    <!-- Action Buttons (Cosumi Style) -->
        <%= if @db_game.status == "pending" do %>
          <!-- Waiting for opponent to accept -->
          <div class="w-full max-w-2xl mb-4">
            <div class="bg-white rounded-lg border-2 border-[#d8cbb3] p-6 shadow-lg text-center">
              <p class="text-lg font-serif text-[#5e4b35] mb-2">Waiting for opponent to join...</p>
              <.link
                navigate={~p"/lobby"}
                class="inline-block px-6 py-2 text-base font-serif text-[#5e4b35] bg-[#e8e0c5] hover:bg-[#d8cbb3] rounded transition-all"
              >
                Back to Lobby
              </.link>
            </div>
          </div>
        <% else %>
          <%= if @game.game_over do %>
            <!-- Game Over - Show Score and Winner -->
            <div class="mb-4 w-full max-w-2xl">
              <%= if @game.score do %>
                <!-- Score Breakdown -->
                <div class="bg-white rounded-lg border-2 border-[#d8cbb3] p-6 mb-4 shadow-lg">
                  <h3 class="text-xl font-serif font-bold text-[#5e4b35] text-center mb-4">
                    Score Result
                  </h3>
                  <div class="flex justify-around mb-4">
                    <!-- Black Score -->
                    <div class="text-center">
                      <div class="w-12 h-12 rounded-full bg-gradient-to-br from-gray-700 to-black shadow-md mx-auto mb-2">
                      </div>
                      <div class="font-serif text-[#5e4b35] font-semibold mb-2">Black</div>
                      <div class="text-sm font-serif text-gray-600">
                        <div>Stones: {@game.score.black.stones}</div>
                        <div>Territory: {@game.score.black.territory}</div>
                        <div class="border-t border-gray-300 mt-1 pt-1 font-bold">
                          Total: {@game.score.black.total}
                        </div>
                      </div>
                    </div>
                    
    <!-- White Score -->
                    <div class="text-center">
                      <div class="w-12 h-12 rounded-full bg-gradient-to-br from-white to-gray-200 shadow-md border border-gray-300 mx-auto mb-2">
                      </div>
                      <div class="font-serif text-[#5e4b35] font-semibold mb-2">White</div>
                      <div class="text-sm font-serif text-gray-600">
                        <div>Stones: {@game.score.white.stones}</div>
                        <div>Territory: {@game.score.white.territory}</div>
                        <div>Komi: {@game.score.white.komi}</div>
                        <div class="border-t border-gray-300 mt-1 pt-1 font-bold">
                          Total: {@game.score.white.total}
                        </div>
                      </div>
                    </div>
                  </div>
                  
    <!-- Winner Announcement -->
                  <div class="text-center text-2xl font-serif font-bold text-[#5e4b35] py-3 bg-[#f3ead7] rounded">
                    {if @game.winner == :black, do: "Black", else: "White"} wins!
                  </div>
                </div>
              <% else %>
                <!-- Resign - No Score -->
                <div class="bg-white rounded-lg border-2 border-[#d8cbb3] p-6 mb-4 shadow-lg">
                  <div class="text-center text-2xl font-serif font-bold text-[#5e4b35]">
                    {if @game.winner == :black, do: "Black", else: "White"} wins!
                  </div>
                </div>
              <% end %>

              <div class="text-center">
                <.link
                  navigate={~p"/lobby"}
                  class="inline-block px-8 py-3 text-xl font-serif text-white bg-[#5e4b35] hover:bg-[#4a3a28] rounded shadow-md transition-all"
                >
                  Back to Lobby
                </.link>
              </div>
            </div>
          <% else %>
            <div class="w-full max-w-2xl flex justify-between mb-4">
              <button
                phx-click="pass"
                class="w-28 sm:w-32 py-2 text-lg sm:text-xl font-serif text-[#a52a2a] bg-gradient-to-b from-[#f3ead7] to-[#d8cbb3] border border-[#a09070] rounded shadow-md active:translate-y-1 active:shadow-sm hover:brightness-105 transition-all"
              >
                Count
              </button>

              <button
                phx-click="resign"
                data-confirm="Are you sure you want to resign?"
                class="w-28 sm:w-32 py-2 text-lg sm:text-xl font-serif text-[#a52a2a] bg-gradient-to-b from-[#f3ead7] to-[#d8cbb3] border border-[#a09070] rounded shadow-md active:translate-y-1 active:shadow-sm hover:brightness-105 transition-all"
              >
                Resign
              </button>
            </div>
          <% end %>
        <% end %>
        
    <!-- Debug Info (Optional) -->
        <div class="text-xs text-gray-400 font-mono text-center">
          Current turn: {@game.turn} | History: {length(@game.history)} moves
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "game_updated", payload: payload}, socket) do
    # Reload the game from database to get updated status
    db_game = Games.get_game!(socket.assigns.game_id)

    # If game status changed to in_progress, start the clock
    if socket.assigns.db_game.status == "pending" and db_game.status == "in_progress" do
      schedule_tick()
    end

    updated_socket = assign(socket, db_game: db_game)

    # If payload has game state, update it and clear flash
    updated_socket =
      if Map.has_key?(payload, :game) do
        updated_socket
        |> clear_flash()
        |> assign(game: payload.game)
      else
        updated_socket
      end

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    game = socket.assigns.game

    # Don't tick if game is over
    if game.game_over do
      {:noreply, socket}
    else
      # Calculate elapsed time since turn started
      now = System.system_time(:second)
      elapsed = if game.turn_started_at, do: now - game.turn_started_at, else: 0

      # Update the current player's time
      updated_game =
        case game.turn do
          :black -> %{game | black_time: max(0, game.black_time - elapsed), turn_started_at: now}
          :white -> %{game | white_time: max(0, game.white_time - elapsed), turn_started_at: now}
        end

      # Check if time ran out
      if updated_game.black_time == 0 or updated_game.white_time == 0 do
        # Time's up! Determine winner
        winner = if updated_game.black_time == 0, do: :white, else: :black
        final_game = %{updated_game | game_over: true, winner: winner}

        # Save final state to database
        Games.update_game_state(socket.assigns.db_game, final_game)

        # Broadcast game over
        GoGameWeb.Endpoint.broadcast("game:#{socket.assigns.game_id}", "game_updated", %{
          game: final_game
        })

        {:noreply, assign(socket, game: final_game)}
      else
        # Just update UI, don't save to database every second
        schedule_tick()
        {:noreply, assign(socket, game: updated_game)}
      end
    end
  end

  @impl true
  def handle_event("make_move", %{"x" => x, "y" => y}, socket) do
    # 1. Check if it's the current user's turn
    if socket.assigns.game.turn != socket.assigns.current_player_color do
      {:noreply, socket}
    else
      # 2. Parse coordinates
      x = String.to_integer(x)
      y = String.to_integer(y)

      # 3. Attempt the move
      case Rules.make_move(socket.assigns.game, x, y) do
        {:ok, new_game} ->
          # 4. Save the game state to database
          Games.update_game_state(socket.assigns.db_game, new_game)

          # 5. Broadcast the update to all players watching this game
          GoGameWeb.Endpoint.broadcast("game:#{socket.assigns.game_id}", "game_updated", %{
            game: new_game
          })

          # Clear any previous error flash and update game
          {:noreply,
           socket
           |> clear_flash()
           |> assign(game: new_game)}

        {:error, reason} ->
          # Show specific error messages (Suicide, Ko, etc)
          error_msg =
            case reason do
              :ko -> "Illegal move: Ko rule (cannot repeat board state)"
              :suicide -> "Illegal move: Suicide not allowed"
              :occupied -> "This position is already occupied"
              :out_of_bounds -> "Move is outside the board"
            end

          {:noreply, put_flash(socket, :error, error_msg)}
      end
    end
  end

  @impl true
  def handle_event("pass", _params, socket) do
    # Check if it's the current user's turn
    if socket.assigns.game.turn != socket.assigns.current_player_color do
      {:noreply, socket}
    else
      {:ok, new_game} = Rules.request_count(socket.assigns.game)

      # Save the game state to database
      Games.update_game_state(socket.assigns.db_game, new_game)

      # Broadcast the update to all players watching this game
      GoGameWeb.Endpoint.broadcast("game:#{socket.assigns.game_id}", "game_updated", %{
        game: new_game
      })

      {:noreply,
       socket
       |> put_flash(:info, "Count requested, waiting for opponent's response")
       |> assign(game: new_game)}
    end
  end

  @impl true
  def handle_event("accept_count", _params, socket) do
    # Opponent accepts the count request
    {:ok, new_game} = Rules.accept_count(socket.assigns.game)

    # Save the game state to database
    Games.update_game_state(socket.assigns.db_game, new_game)

    # Broadcast the update to all players watching this game
    GoGameWeb.Endpoint.broadcast("game:#{socket.assigns.game_id}", "game_updated", %{
      game: new_game
    })

    {:noreply,
     socket
     |> put_flash(:info, "Count accepted, game over")
     |> assign(game: new_game)}
  end

  @impl true
  def handle_event("reject_count", _params, socket) do
    # Opponent rejects the count request
    {:ok, new_game} = Rules.reject_count(socket.assigns.game)

    # Save the game state to database
    Games.update_game_state(socket.assigns.db_game, new_game)

    # Broadcast the update to all players watching this game
    GoGameWeb.Endpoint.broadcast("game:#{socket.assigns.game_id}", "game_updated", %{
      game: new_game
    })

    {:noreply,
     socket
     |> put_flash(:info, "Count declined, game continues")
     |> assign(game: new_game)}
  end

  @impl true
  def handle_event("resign", _params, socket) do
    # Check if it's the current user's turn (can resign on your turn)
    if socket.assigns.current_player_color do
      {:ok, new_game} = Rules.resign(socket.assigns.game, socket.assigns.current_player_color)

      # Save the game state to database
      Games.update_game_state(socket.assigns.db_game, new_game)

      # Broadcast the update to all players watching this game
      GoGameWeb.Endpoint.broadcast("game:#{socket.assigns.game_id}", "game_updated", %{
        game: new_game
      })

      {:noreply, assign(socket, game: new_game)}
    else
      {:noreply, socket}
    end
  end

  # Helper function to format time in MM:SS
  defp format_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  # Schedule a tick message every second
  defp schedule_tick do
    Process.send_after(self(), :tick, 1000)
  end
end
