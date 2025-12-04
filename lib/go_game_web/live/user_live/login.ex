defmodule GoGameWeb.UserLive.Login do
  use GoGameWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f3ead7] flex items-center justify-center py-12 px-4">
      <.flash_group flash={@flash} />
      <div class="max-w-md w-full">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-5xl font-serif text-[#5e4b35] mb-3">9×9 Go</h1>
          <p class="text-lg text-[#8b7355] font-serif">Online Go Game</p>
        </div>
        
    <!-- Login Card -->
        <div class="bg-white rounded-lg shadow-2xl p-8 border-2 border-[#d8cbb3]">
          <h2 class="text-2xl font-serif text-[#5e4b35] text-center mb-6">Login</h2>
          
    <!-- Password Form -->
          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <div>
              <label class="block text-sm font-serif font-semibold text-[#5e4b35] mb-2">
                Username
              </label>
              <.input
                field={f[:username]}
                type="text"
                autocomplete="username"
                required
                phx-mounted={JS.focus()}
                class="w-full px-4 py-2 border-2 border-[#d8cbb3] rounded focus:border-[#dcb35c] focus:outline-none"
              />
            </div>
            <div>
              <label class="block text-sm font-serif font-semibold text-[#5e4b35] mb-2">
                Password
              </label>
              <.input
                field={@form[:password]}
                type="password"
                autocomplete="current-password"
                class="w-full px-4 py-2 border-2 border-[#d8cbb3] rounded focus:border-[#dcb35c] focus:outline-none"
              />
            </div>
            <button
              type="submit"
              name={@form[:remember_me].name}
              value="true"
              class="w-full bg-[#dcb35c] hover:bg-[#cda24b] text-[#5e4b35] font-serif font-semibold py-3 px-4 rounded shadow-md transition"
            >
              Login and stay logged in
            </button>
            <button
              type="submit"
              class="w-full bg-[#e8e0c5] hover:bg-[#d8cbb3] text-[#5e4b35] font-serif font-semibold py-3 px-4 rounded shadow transition"
            >
              Login for this session only
            </button>
          </.form>
        </div>
        
    <!-- Sign Up Link -->
        <div :if={!@current_scope} class="text-center mt-6">
          <p class="text-[#8b7355] font-serif">
            Don't have an account?
            <.link navigate={~p"/users/register"} class="text-[#5e4b35] font-semibold hover:underline">
              Register
            </.link>
          </p>
        </div>
        
    <!-- Skip Login Link -->
        <div class="text-center mt-4">
          <.link
            navigate={~p"/lobby"}
            class="text-[#8b7355] hover:text-[#5e4b35] font-serif text-sm transition-colors"
          >
            Skip login, continue as guest
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    username =
      Phoenix.Flash.get(socket.assigns.flash, :username) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:username)])

    form = to_form(%{"username" => username}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
