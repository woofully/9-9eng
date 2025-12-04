defmodule GoGame.Social do
  @moduledoc """
  The Social context.
  """

  import Ecto.Query, warn: false
  alias GoGame.Repo
  alias GoGame.Social.Friendship
  # alias GoGame.Accounts.User

  ## Friendships

  # List all "accepted" friends for a user
  def list_friends(user) do
    # Find rows where user is either requester OR addressee, AND status is accepted
    query =
      from f in Friendship,
        where:
          (f.requester_id == ^user.id or f.addressee_id == ^user.id) and f.status == "accepted",
        preload: [:requester, :addressee]

    Repo.all(query)
    |> Enum.map(fn f ->
      if f.requester_id == user.id, do: f.addressee, else: f.requester
    end)
  end

  # List pending requests sent TO the user
  def list_pending_requests(user) do
    query =
      from f in Friendship,
        where: f.addressee_id == ^user.id and f.status == "pending",
        preload: [:requester]

    Repo.all(query)
  end

  # Send a friend request
  def send_friend_request(requester, addressee) do
    %Friendship{}
    |> Friendship.changeset(%{
      requester_id: requester.id,
      addressee_id: addressee.id,
      status: "pending"
    })
    |> Repo.insert()
  end

  # Accept a request
  def accept_friend_request(%Friendship{} = friendship) do
    friendship
    |> Friendship.changeset(%{status: "accepted"})
    |> Repo.update()
  end

  # Block a user
  # This tries to update an existing relationship to "blocked" or creates a new one
  def block_user(blocker, blocked_user) do
    # Check if a relationship already exists (in either direction)
    query =
      from f in Friendship,
        where:
          (f.requester_id == ^blocker.id and f.addressee_id == ^blocked_user.id) or
            (f.requester_id == ^blocked_user.id and f.addressee_id == ^blocker.id)

    case Repo.one(query) do
      nil ->
        # Create new blocked relationship
        send_friend_request(blocker, blocked_user)
        |> case do
          {:ok, f} ->
            f
            |> Friendship.changeset(%{status: "blocked"})
            |> Repo.update()

          error ->
            error
        end

      friendship ->
        friendship
        |> Friendship.changeset(%{status: "blocked"})
        |> Repo.update()
    end
  end

  def get_friendship!(id), do: Repo.get!(Friendship, id)

  def delete_friendship(%Friendship{} = friendship) do
    Repo.delete(friendship)
  end
end
