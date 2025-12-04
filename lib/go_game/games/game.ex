defmodule GoGame.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  alias GoGame.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "games" do
    belongs_to :black_player, User, type: :integer
    belongs_to :white_player, User, type: :integer
    belongs_to :winner, User, type: :integer

    field :status, :string, default: "pending"
    field :game_state, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:black_player_id, :white_player_id, :status, :game_state, :winner_id])
    |> validate_required([:black_player_id, :status])
    |> validate_inclusion(:status, ["pending", "in_progress", "completed", "cancelled"])
    |> foreign_key_constraint(:black_player_id)
    |> foreign_key_constraint(:white_player_id)
    |> foreign_key_constraint(:winner_id)
  end
end
