defmodule GoGame.SocialFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GoGame.Social` context.
  """

  @doc """
  Generate a friendship.
  By default, it creates two new users and establishes an accepted friendship.
  """
  def friendship_fixture(attrs \\ %{}) do
    # 1. Ensure attrs is a Map (handles keyword lists safely)
    attrs = Enum.into(attrs, %{})

    # 2. Ensure we have two users
    requester = attrs[:requester] || GoGame.AccountsFixtures.user_fixture()
    addressee = attrs[:addressee] || GoGame.AccountsFixtures.user_fixture()

    # 3. Create the request
    {:ok, friendship} = GoGame.Social.send_friend_request(requester, addressee)

    # 4. Handle status (default to "accepted")
    status = Map.get(attrs, :status, "accepted")

    if status == "accepted" do
      {:ok, updated_friendship} = GoGame.Social.accept_friend_request(friendship)
      updated_friendship
    else
      friendship
    end
  end
end
