defmodule GoGame.Gameplay.Rules do
  @moduledoc """
  Pure functional Core Logic for 9x9 Go.
  """

  # Map %{{x,y} => :black | :white}
  defstruct board: %{},
            # :black | :white
            turn: :black,
            captures: %{black: 0, white: 0},
            # List of previous board states (for Ko checks)
            history: [],
            # List of moves [{:black, {x,y}}, ...] (for SGF)
            moves: [],
            # Track if previous move was a pass (for game end)
            passed: false,
            # :black | :white | nil - who requested to count points
            count_requested_by: nil,
            # Black player's time in seconds (10 minutes)
            black_time: 600,
            # White player's time in seconds (10 minutes)
            white_time: 600,
            # Unix timestamp when current turn started
            turn_started_at: nil,
            # Track if game has ended
            game_over: false,
            # :black | :white | nil
            winner: nil,
            # Score details: %{black: %{stones: N, territory: N, total: N}, white: %{...}}
            score: nil

  @board_size 9
  # 10 minutes in seconds
  @initial_time 600

  # --- Public API ---

  def new do
    %__MODULE__{
      black_time: @initial_time,
      white_time: @initial_time,
      turn_started_at: System.system_time(:second)
    }
  end

  def make_move(game, x, y) do
    with :ok <- validate_bounds(x, y),
         :ok <- validate_empty(game.board, x, y) do
      # 1. Place stone tentatively
      opponent = opponent_color(game.turn)
      tentative_board = Map.put(game.board, {x, y}, game.turn)

      # 2. Check for captures (Opponent stones surrounding the new move)
      {board_after_captures, captured_count} = process_captures(tentative_board, {x, y}, opponent)

      # 3. Check for Suicide (My new stone has 0 liberties and didn't capture anything)
      # We check the group belonging to the stone we just placed
      if captured_count == 0 and count_liberties(board_after_captures, {x, y}) == 0 do
        {:error, :suicide}
      else
        # 4. Check for Ko (Does this board state match the immediate previous one?)
        # We only check history if there is one.
        case check_ko(board_after_captures, game.history) do
          :error ->
            {:error, :ko}

          :ok ->
            # 5. Success - Update State with time deduction
            now = System.system_time(:second)
            elapsed = if game.turn_started_at, do: now - game.turn_started_at, else: 0

            # Deduct time from current player
            {black_time, white_time} =
              case game.turn do
                :black -> {max(0, game.black_time - elapsed), game.white_time}
                :white -> {game.black_time, max(0, game.white_time - elapsed)}
              end

            new_captures = Map.update!(game.captures, game.turn, &(&1 + captured_count))

            {:ok,
             %{
               game
               | board: board_after_captures,
                 turn: opponent,
                 captures: new_captures,
                 # Prepend OLD board to history
                 history: [game.board | game.history],
                 moves: [{game.turn, {x, y}} | game.moves],
                 passed: false,
                 # Clear count request when move is made
                 count_requested_by: nil,
                 black_time: black_time,
                 white_time: white_time,
                 turn_started_at: now
             }}
        end
      end
    end
  end

  def request_count(game) do
    # Current player requests to count points
    # The opponent will need to accept or reject
    now = System.system_time(:second)
    elapsed = if game.turn_started_at, do: now - game.turn_started_at, else: 0

    # Deduct time from current player
    {black_time, white_time} =
      case game.turn do
        :black -> {max(0, game.black_time - elapsed), game.white_time}
        :white -> {game.black_time, max(0, game.white_time - elapsed)}
      end

    {:ok,
     %{
       game
       | count_requested_by: game.turn,
         turn: opponent_color(game.turn),
         history: [game.board | game.history],
         moves: [{game.turn, :request_count} | game.moves],
         passed: true,
         black_time: black_time,
         white_time: white_time,
         turn_started_at: now
     }}
  end

  def accept_count(game) do
    # Opponent accepts the count request - end game and count points
    {winner, score} = calculate_winner_and_score(game)
    {:ok, %{game | game_over: true, winner: winner, score: score, count_requested_by: nil}}
  end

  def reject_count(game) do
    # Opponent rejects the count request - game continues
    {:ok, %{game | count_requested_by: nil, passed: false}}
  end

  # Keep the old pass function for backward compatibility (two consecutive passes)
  def pass(game) do
    request_count(game)
  end

  def resign(game, color) do
    # End the game, the opponent wins
    winner = opponent_color(color)
    {:ok, %{game | game_over: true, winner: winner}}
  end

  def to_sgf(game) do
    # Standard SGF header for 9x9
    header = "(;GM[1]FF[4]SZ[9]KM[6.5]RU[Japanese]"

    moves_str =
      game.moves
      |> Enum.reverse()
      |> Enum.map(fn {color, move} ->
        c_str = if color == :black, do: "B", else: "W"

        coord_str =
          case move do
            :pass ->
              ""

            {x, y} ->
              # SGF uses 'a'-'s'. 0->a, 1->b
              req_x = List.to_string([?a + x])
              req_y = List.to_string([?a + y])
              req_x <> req_y
          end

        ";#{c_str}[#{coord_str}]"
      end)
      |> Enum.join("")

    header <> moves_str <> ")"
  end

  # --- Private Helpers ---

  defp validate_bounds(x, y) do
    if x >= 0 and x < @board_size and y >= 0 and y < @board_size do
      :ok
    else
      {:error, :out_of_bounds}
    end
  end

  defp validate_empty(board, x, y) do
    if Map.has_key?(board, {x, y}) do
      {:error, :occupied}
    else
      :ok
    end
  end

  defp opponent_color(:black), do: :white
  defp opponent_color(:white), do: :black

  defp check_ko(new_board, [previous_board | _]) when new_board == previous_board, do: :error
  defp check_ko(_, _), do: :ok

  # Returns {new_board, captured_count}
  defp process_captures(board, {x, y}, opponent_color) do
    # Check all 4 neighbors. If they belong to opponent, check their group's liberties.
    neighbors = get_neighbors({x, y})

    {final_board, total_captured} =
      Enum.reduce(neighbors, {board, 0}, fn neighbor, {acc_board, acc_count} ->
        if Map.get(acc_board, neighbor) == opponent_color do
          # It's an opponent. Find their group.
          group = get_group(acc_board, neighbor, opponent_color)

          # Count liberties of this group
          if count_liberties(acc_board, group) == 0 do
            # CAPTURE! Remove stones from board
            new_board = Enum.reduce(group, acc_board, fn pos, b -> Map.delete(b, pos) end)
            {new_board, acc_count + length(group)}
          else
            {acc_board, acc_count}
          end
        else
          {acc_board, acc_count}
        end
      end)

    {final_board, total_captured}
  end

  # --- Flood Fill Logic (The "Brain") ---

  # Returns a list of coordinates belonging to the connected group at {x,y}
  defp get_group(board, {start_x, start_y}, color) do
    do_get_group(board, [{start_x, start_y}], MapSet.new([{start_x, start_y}]), color)
  end

  defp do_get_group(_board, [], visited, _color), do: MapSet.to_list(visited)

  defp do_get_group(board, [current | rest], visited, color) do
    neighbors =
      get_neighbors(current)
      |> Enum.filter(fn pos ->
        Map.get(board, pos) == color and not MapSet.member?(visited, pos)
      end)

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    do_get_group(board, rest ++ neighbors, new_visited, color)
  end

  # Returns number of empty intersections surrounding a group
  defp count_liberties(board, group) when is_list(group) do
    group
    # Get all neighbors of all stones
    |> Enum.flat_map(&get_neighbors/1)
    # Remove duplicates
    |> Enum.uniq()
    # Keep only empty spots
    |> Enum.filter(fn pos -> not Map.has_key?(board, pos) end)
    |> length()
  end

  defp count_liberties(board, single_stone),
    do: count_liberties(board, get_group(board, single_stone, Map.get(board, single_stone)))

  defp get_neighbors({x, y}) do
    [{x, y - 1}, {x, y + 1}, {x - 1, y}, {x + 1, y}]
    |> Enum.filter(fn {nx, ny} ->
      nx >= 0 and nx < @board_size and ny >= 0 and ny < @board_size
    end)
  end

  # --- Scoring ---

  # Calculate winner and detailed score based on Chinese (area) scoring with 6.5 komi
  defp calculate_winner_and_score(game) do
    # Count stones on board for each player
    black_stones = Enum.count(game.board, fn {_, color} -> color == :black end)
    white_stones = Enum.count(game.board, fn {_, color} -> color == :white end)

    # Calculate territory (empty intersections controlled by each player)
    {black_territory, white_territory} = calculate_territory(game.board)

    # Calculate final scores (Chinese rules: stones + territory + komi)
    black_total = black_stones + black_territory
    white_total = white_stones + white_territory + 6.5

    winner = if black_total > white_total, do: :black, else: :white

    score = %{
      black: %{
        stones: black_stones,
        territory: black_territory,
        total: black_total
      },
      white: %{
        stones: white_stones,
        territory: white_territory,
        komi: 6.5,
        total: white_total
      }
    }

    {winner, score}
  end

  # Calculate territory for each player
  defp calculate_territory(board) do
    # Find all empty intersections
    all_positions = for x <- 0..(@board_size - 1), y <- 0..(@board_size - 1), do: {x, y}
    empty_positions = Enum.filter(all_positions, fn pos -> not Map.has_key?(board, pos) end)

    # Group empty positions into territories using flood fill
    territories = find_territories(board, empty_positions, MapSet.new(), [])

    # Count territory for each player
    Enum.reduce(territories, {0, 0}, fn territory, {black_acc, white_acc} ->
      case determine_territory_owner(board, territory) do
        :black -> {black_acc + length(territory), white_acc}
        :white -> {black_acc, white_acc + length(territory)}
        # Neutral territory (dame) counts for no one
        :neutral -> {black_acc, white_acc}
      end
    end)
  end

  # Find all connected empty regions (territories)
  defp find_territories(_board, [], _visited, acc), do: acc

  defp find_territories(board, [pos | rest], visited, acc) do
    if MapSet.member?(visited, pos) do
      find_territories(board, rest, visited, acc)
    else
      # Flood fill to find connected empty region
      territory = flood_fill_empty(board, [pos], MapSet.new([pos]))
      new_visited = Enum.reduce(territory, visited, &MapSet.put(&2, &1))
      find_territories(board, rest, new_visited, [territory | acc])
    end
  end

  # Flood fill to find connected empty intersections
  defp flood_fill_empty(_board, [], visited), do: MapSet.to_list(visited)

  defp flood_fill_empty(board, [current | rest], visited) do
    neighbors =
      get_neighbors(current)
      |> Enum.filter(fn pos ->
        not Map.has_key?(board, pos) and not MapSet.member?(visited, pos)
      end)

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    flood_fill_empty(board, rest ++ neighbors, new_visited)
  end

  # Determine who owns a territory by checking what colors border it
  defp determine_territory_owner(board, territory) do
    # Get all neighboring stones
    bordering_colors =
      territory
      |> Enum.flat_map(&get_neighbors/1)
      |> Enum.filter(fn pos -> Map.has_key?(board, pos) end)
      |> Enum.map(fn pos -> Map.get(board, pos) end)
      |> Enum.uniq()

    case bordering_colors do
      [:black] -> :black
      [:white] -> :white
      # Bordered by both colors or no stones
      _ -> :neutral
    end
  end
end
