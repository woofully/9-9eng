defmodule GoGame.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :black_player_id, references(:users, on_delete: :delete_all), null: false
      add :white_player_id, references(:users, on_delete: :delete_all)
      add :status, :string, null: false, default: "pending"
      add :game_state, :map, default: %{}
      add :winner_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:black_player_id])
    create index(:games, [:white_player_id])
    create index(:games, [:status])
  end
end
