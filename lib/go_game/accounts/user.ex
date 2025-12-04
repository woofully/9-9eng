defmodule GoGame.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :is_guest, :boolean, default: false

    # This virtual field is required by the session system to track login time
    field :authenticated_at, :naive_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.
  Email is optional - users can register with just username and password.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :username])
    |> validate_username()
    |> validate_email(Keyword.put(opts, :allow_no_email, true))
    |> validate_password(opts)
  end

  @doc """
  A user changeset for guest user creation.
  """
  def guest_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:username])
    |> put_change(:is_guest, true)
    |> validate_required([:username])
    |> unique_constraint(:username)
  end

  @doc """
  A user changeset for converting guest to registered user.
  """
  def guest_to_registered_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :password])
    |> put_change(:is_guest, false)
    |> validate_username()
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    # Email is optional if allow_no_email is true
    allow_no_email = Keyword.get(opts, :allow_no_email, false)

    if allow_no_email do
      changeset
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: "must contain @ symbol and no spaces"
      )
      |> validate_length(:email, max: 160)
      |> unsafe_validate_unique(:email, GoGame.Repo)
      |> unique_constraint(:email, message: "this email is already taken")
    else
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: "must contain @ symbol and no spaces"
      )
      |> validate_length(:email, max: 160)
      |> unsafe_validate_unique(:email, GoGame.Repo)
      |> unique_constraint(:email, message: "this email is already taken")
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 3, max: 72)
    |> maybe_hash_password(opts)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers, and underscores allowed"
    )
    |> unsafe_validate_unique(:username, GoGame.Repo)
    |> unique_constraint(:username)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "email has not changed")
    end
  end

  @doc """
  A user changeset for changing the username.
  """
  def username_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:username])
    |> validate_username()
    |> case do
      %{changes: %{username: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :username, "username has not changed")
    end
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "passwords do not match")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.
  """
  def valid_password?(%GoGame.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "password is incorrect")
    end
  end
end
