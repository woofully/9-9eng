defmodule GoGame.Repo.Migrations.AddGuestUserSupport do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_guest, :boolean, default: false, null: false
      modify :email, :string, null: true, from: {:string, null: false}
      modify :hashed_password, :string, null: true, from: {:string, null: false}
    end
  end
end
