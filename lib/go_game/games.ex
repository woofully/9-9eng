defmodule GoGame.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias GoGame.Repo
  alias GoGame.Games.Game
  alias GoGame.Accounts.User
  alias GoGame.Gameplay.Rules

  @doc """
  Creates a game with the given creator as black player.
  """
  def create_game(%User{} = creator, attrs \\ %{}) do
    %Game{}
    |> Game.changeset(Map.put(attrs, :black_player_id, creator.id))
    |> Repo.insert()
  end

  @doc """
  Gets a single game.
  """
  def get_game!(id) do
    Repo.get!(Game, id)
    |> Repo.preload([:black_player, :white_player, :winner])
  end

  @doc """
  Joins a game as the white player.
  """
  def join_game(%Game{} = game, %User{} = user) do
    game
    |> Game.changeset(%{white_player_id: user.id, status: "in_progress"})
    |> Repo.update()
  end

  @doc """
  Updates the game state.
  """
  def update_game_state(%Game{} = game, %Rules{} = rules) do
    serialized_state = serialize_game_state(rules)

    # If game is over, also update status and winner_id
    attrs =
      if rules.game_over do
        winner_id =
          case rules.winner do
            :black -> game.black_player_id
            :white -> game.white_player_id
            _ -> nil
          end

        %{game_state: serialized_state, status: "completed", winner_id: winner_id}
      else
        %{game_state: serialized_state}
      end

    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all pending games.
  """
  def list_pending_games do
    Repo.all(from g in Game, where: g.status == "pending", preload: [:black_player])
  end

  @doc """
  Lists all games for a user (both as black or white player).
  """
  def list_user_games(user_id) do
    Repo.all(
      from g in Game,
        where:
          (g.black_player_id == ^user_id or g.white_player_id == ^user_id) and
            g.status in ["pending", "in_progress"],
        order_by: [desc: g.updated_at],
        preload: [:black_player, :white_player]
    )
  end

  @doc """
  Cancels a game (sets status to "cancelled").
  """
  def cancel_game(%Game{} = game) do
    game
    |> Game.changeset(%{status: "cancelled"})
    |> Repo.update()
  end

  @doc """
  Serializes a Rules struct to a JSON-safe map for database storage.
  Converts tuple keys in board and history to strings.
  """
  def serialize_game_state(%Rules{} = rules) do
    %{
      board: serialize_board(rules.board),
      turn: rules.turn,
      captures: rules.captures,
      history: Enum.map(rules.history, &serialize_board/1),
      moves: Enum.map(rules.moves, &serialize_move/1),
      passed: rules.passed,
      black_time: rules.black_time,
      white_time: rules.white_time,
      turn_started_at: rules.turn_started_at,
      game_over: rules.game_over,
      winner: rules.winner
    }
  end

  @doc """
  Deserializes a JSON map back to a Rules struct.
  Converts string keys back to tuples.
  """
  def deserialize_game_state(state_map) when is_map(state_map) do
    %Rules{
      board: deserialize_board(state_map["board"] || %{}),
      turn: String.to_existing_atom(state_map["turn"] || "black"),
      captures: %{
        black: state_map["captures"]["black"] || 0,
        white: state_map["captures"]["white"] || 0
      },
      history: Enum.map(state_map["history"] || [], &deserialize_board/1),
      moves: Enum.map(state_map["moves"] || [], &deserialize_move/1),
      passed: state_map["passed"] || false,
      black_time: state_map["black_time"] || 600,
      white_time: state_map["white_time"] || 600,
      turn_started_at: state_map["turn_started_at"],
      game_over: state_map["game_over"] || false,
      winner: if(state_map["winner"], do: String.to_existing_atom(state_map["winner"]), else: nil)
    }
  end

  # Convert board with tuple keys to string keys: %{{4,4} => :black} -> %{"4,4" => "black"}
  defp serialize_board(board) do
    board
    |> Enum.map(fn {{x, y}, color} -> {"#{x},#{y}", Atom.to_string(color)} end)
    |> Enum.into(%{})
  end

  # Convert board with string keys back to tuple keys: %{"4,4" => "black"} -> %{{4,4} => :black}
  defp deserialize_board(board) do
    board
    |> Enum.map(fn {key, color} ->
      [x, y] = String.split(key, ",") |> Enum.map(&String.to_integer/1)
      {{x, y}, String.to_existing_atom(color)}
    end)
    |> Enum.into(%{})
  end

  # Serialize a move: {:black, {4, 4}} -> ["black", [4, 4]] or {:black, :pass} -> ["black", "pass"]
  defp serialize_move({color, :pass}), do: [Atom.to_string(color), "pass"]
  defp serialize_move({color, :request_count}), do: [Atom.to_string(color), "request_count"]
  defp serialize_move({color, {x, y}}), do: [Atom.to_string(color), [x, y]]

  # Deserialize a move: ["black", [4, 4]] -> {:black, {4, 4}} or ["black", "pass"] -> {:black, :pass}
  defp deserialize_move([color, "pass"]), do: {String.to_existing_atom(color), :pass}

  defp deserialize_move([color, "request_count"]),
    do: {String.to_existing_atom(color), :request_count}

  defp deserialize_move([color, [x, y]]), do: {String.to_existing_atom(color), {x, y}}
end
