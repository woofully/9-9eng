defmodule GoGameWeb.UserLive.Settings do
  use GoGameWeb, :live_view

  alias GoGame.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f3ead7] py-8 px-4">
      <div class="mx-auto max-w-2xl">
        <div class="bg-white rounded-lg shadow-xl border-2 border-[#d8cbb3] p-8">
          <!-- Back to Lobby Link -->
          <div class="mb-4">
            <.link
              navigate={~p"/lobby"}
              class="inline-flex items-center text-[#5e4b35] hover:text-[#4a3a28] font-serif transition-colors"
            >
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M10 19l-7-7m0 0l7-7m-7 7h18"
                />
              </svg>
              Back to Lobby
            </.link>
          </div>

          <h1 class="text-3xl font-serif font-bold text-[#5e4b35] mb-2 text-center">
            Account Settings
          </h1>
          <p class="text-center text-[#8b7355] mb-8 font-serif">Manage your username and password</p>

          <div class="space-y-8">
            <!-- Username Section -->
            <div class="pb-8 border-b border-[#e8e0c5]">
              <h2 class="text-xl font-serif font-semibold text-[#5e4b35] mb-4">Change Username</h2>
              <.simple_form
                for={@username_form}
                id="username_form"
                phx-submit="update_username"
                phx-change="validate_username"
              >
                <.input field={@username_form[:username]} type="text" label="Username" required />
                <.input
                  field={@username_form[:current_password]}
                  name="current_password"
                  id="current_password_for_username"
                  type="password"
                  label="Current password"
                  value={@username_form_current_password}
                  required
                />
                <:actions>
                  <.button
                    class="w-full bg-[#5e4b35] hover:bg-[#4a3a28] text-white font-serif py-3 rounded-lg transition-colors"
                    phx-disable-with="Changing..."
                  >
                    Change Username
                  </.button>
                </:actions>
              </.simple_form>
            </div>
            
    <!-- Password Section -->
            <div>
              <h2 class="text-xl font-serif font-semibold text-[#5e4b35] mb-4">Change Password</h2>
              <.simple_form
                for={@password_form}
                id="password_form"
                action={~p"/users/log-in?_action=password_updated"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
              >
                <.input
                  field={@password_form[:username]}
                  type="hidden"
                  id="hidden_user_username"
                  value={@current_username}
                />
                <.input
                  field={@password_form[:password]}
                  type="password"
                  label="New password"
                  required
                />
                <.input
                  field={@password_form[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                />
                <.input
                  field={@password_form[:current_password]}
                  name="current_password"
                  type="password"
                  label="Current password"
                  id="current_password_for_password"
                  value={@current_password}
                  required
                />
                <:actions>
                  <.button
                    class="w-full bg-[#5e4b35] hover:bg-[#4a3a28] text-white font-serif py-3 rounded-lg transition-colors"
                    phx-disable-with="Changing..."
                  >
                    Change Password
                  </.button>
                </:actions>
              </.simple_form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    username_changeset = Accounts.change_user_username(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:username_form_current_password, nil)
      |> assign(:current_username, user.username)
      |> assign(:username_form, to_form(username_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_username", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    username_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_username(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, username_form: username_form, username_form_current_password: password)}
  end

  def handle_event("update_username", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_username(user, password, user_params) do
      {:ok, updated_user} ->
        info = "Username changed successfully."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> assign(username_form_current_password: nil, current_username: updated_user.username)}

      {:error, changeset} ->
        {:noreply, assign(socket, :username_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
