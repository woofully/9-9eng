defmodule GoGame.Repo.Migrations.ConvertGamesToUuid do
  use Ecto.Migration

  def up do
    # Drop the old games table
    drop table(:games)

    # Create new games table with UUID primary key
    create table(:games, primary_key: false) do
      add :id, :binary_id, primary_key: true
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

  def down do
    drop table(:games)

    # Recreate the old integer-based table
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
