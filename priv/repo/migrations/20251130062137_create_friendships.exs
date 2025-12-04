# priv/repo/migrations/TIMESTAMP_create_friendships.exs
defmodule GoGame.Repo.Migrations.CreateFriendships do
  use Ecto.Migration

  def change do
    create table(:friendships) do
      add :status, :string, null: false, default: "pending"
      add :requester_id, references(:users, on_delete: :delete_all), null: false
      add :addressee_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:friendships, [:requester_id])
    create index(:friendships, [:addressee_id])
    # Ensure a pair of users can only have one relationship entry between them
    create unique_index(:friendships, [:requester_id, :addressee_id])
  end
end
