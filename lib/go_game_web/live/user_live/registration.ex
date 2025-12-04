defmodule GoGameWeb.UserLive.Registration do
  use GoGameWeb, :live_view

  alias GoGame.Accounts
  alias GoGame.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f3ead7] flex flex-col items-center justify-center py-8 px-4">
      <div class="w-full max-w-md">
        <div class="bg-white rounded-lg shadow-xl border-2 border-[#d8cbb3] p-8">
          <!-- Title -->
          <h1 class="text-3xl font-serif font-bold text-[#5e4b35] mb-2 text-center">
            Create Account
          </h1>
          <p class="text-center text-[#8b7355] mb-6 font-serif">
            Already have an account?
            <.link navigate={~p"/users/log-in"} class="font-semibold text-[#5e4b35] hover:underline">
              Log in now
            </.link>
          </p>

          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log-in?_action=registered"}
            method="post"
          >
            <.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>

            <.input field={@form[:username]} type="text" label="Username" required />
            <.input field={@form[:password]} type="password" label="Password" required />

            <:actions>
              <.button
                phx-disable-with="Creating..."
                class="w-full bg-[#5e4b35] hover:bg-[#4a3a28] text-white font-serif py-3 rounded-lg transition-colors"
              >
                Create Account
              </.button>
            </:actions>
          </.simple_form>
          
    <!-- Guest info -->
          <div class="mt-6 text-center">
            <p class="text-sm text-[#8b7355] font-serif mb-3">Register to save your game history</p>
            <.link
              navigate={~p"/lobby"}
              class="inline-block px-6 py-2 text-[#5e4b35] bg-[#e8e0c5] hover:bg-[#d8cbb3] rounded-lg font-serif transition-colors"
            >
              Skip registration, continue playing
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    {:ok, socket |> assign(trigger_submit: false, check_errors: false) |> assign_form(changeset)}
  end

  # --- THIS IS THE FUNCTION THAT WAS BROKEN/MISSING ---
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Successfully saved! Now prepare to redirect.
        # We create a new changeset for the form (clearing the password for security)
        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Validation failed (taken email/username, etc.)
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end
end
