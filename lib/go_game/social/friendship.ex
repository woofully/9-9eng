defmodule GoGame.Social.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "friendships" do
    # pending, accepted, blocked
    field :status, :string, default: "pending"

    belongs_to :requester, GoGame.Accounts.User
    belongs_to :addressee, GoGame.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:status, :requester_id, :addressee_id])
    |> validate_required([:status, :requester_id, :addressee_id])
    |> validate_inclusion(:status, ["pending", "accepted", "blocked"])
    |> validate_not_self_friend()
    |> unique_constraint([:requester_id, :addressee_id], message: "Friend request already exists")
  end

  defp validate_not_self_friend(changeset) do
    requester_id = get_field(changeset, :requester_id)
    addressee_id = get_field(changeset, :addressee_id)

    if requester_id == addressee_id do
      add_error(changeset, :addressee_id, "cannot friend yourself")
    else
      changeset
    end
  end
end
