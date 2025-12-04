defmodule GoGame.SocialTest do
  use GoGame.DataCase

  alias GoGame.Social
  alias GoGame.Social.Friendship

  import GoGame.AccountsFixtures
  import GoGame.SocialFixtures

  describe "friendships" do
    test "send_friend_request/2 creates a pending friendship" do
      user1 = user_fixture()
      user2 = user_fixture()

      assert {:ok, %Friendship{} = friendship} = Social.send_friend_request(user1, user2)
      assert friendship.status == "pending"
      assert friendship.requester_id == user1.id
      assert friendship.addressee_id == user2.id
    end

    test "cannot send friend request to self" do
      user = user_fixture()
      assert {:error, changeset} = Social.send_friend_request(user, user)
      assert "cannot friend yourself" in errors_on(changeset).addressee_id
    end

    test "accept_friend_request/1 updates status to accepted" do
      # Use the fixture to create a pending request first
      friendship = friendship_fixture(status: "pending")

      assert {:ok, %Friendship{} = updated} = Social.accept_friend_request(friendship)
      assert updated.status == "accepted"
    end

    test "list_friends/1 returns only accepted friends" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      # User1 <-> User2 (Accepted)
      {:ok, f1} = Social.send_friend_request(user1, user2)
      Social.accept_friend_request(f1)

      # User1 <-> User3 (Pending)
      Social.send_friend_request(user1, user3)

      friends = Social.list_friends(user1)
      assert length(friends) == 1
      assert hd(friends).id == user2.id
    end

    test "list_pending_requests/1 returns incoming requests" do
      # Requester
      user1 = user_fixture()
      # Addressee
      user2 = user_fixture()

      Social.send_friend_request(user1, user2)

      requests = Social.list_pending_requests(user2)
      assert length(requests) == 1
      assert hd(requests).requester_id == user1.id

      # User 1 should see no pending INCOMING requests
      assert Social.list_pending_requests(user1) == []
    end

    test "block_user/2 blocks an existing friendship" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} = Social.send_friend_request(user1, user2)

      assert {:ok, %Friendship{} = blocked} = Social.block_user(user2, user1)
      assert blocked.status == "blocked"
    end
  end
end
