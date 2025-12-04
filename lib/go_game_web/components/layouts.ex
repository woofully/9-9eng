defmodule GoGameWeb.Layouts do
  use GoGameWeb, :html
  use Phoenix.Component

  embed_templates "layouts/*"

  attr :current_user, :map, required: true

  def user_menu(assigns) do
    ~H"""
    <div class="relative" id="user-menu" phx-click-away={JS.hide(to: "#user-menu-dropdown")}>
      <!-- User Icon Button -->
      <button
        type="button"
        phx-click={JS.toggle(to: "#user-menu-dropdown")}
        class="flex items-center gap-2 px-4 py-2 rounded-lg bg-[#e8e0c5] hover:bg-[#d8cbb3] transition-all"
      >
        <!-- User Icon -->
        <svg class="w-6 h-6 text-[#5e4b35]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
          />
        </svg>
        <!-- Username -->
        <span class="font-serif text-[#5e4b35] font-semibold">
          {if @current_user.is_guest, do: "Guest", else: @current_user.username}
        </span>
        <!-- Dropdown Arrow -->
        <svg class="w-4 h-4 text-[#5e4b35]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      
    <!-- Dropdown Menu (hidden by default, shown on click/tap) -->
      <div
        id="user-menu-dropdown"
        class="hidden absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-xl transition-all duration-200 z-50 border border-[#d8cbb3]"
      >
        <div class="py-2">
          <%= if @current_user.is_guest do %>
            <!-- Guest User Options -->
            <a
              href="/users/register"
              class="block px-4 py-2 text-[#5e4b35] hover:bg-[#f3ead7] font-serif transition-colors"
            >
              Set username and password
            </a>
          <% else %>
            <!-- Registered User Options -->
            <a
              href="/users/settings"
              class="block px-4 py-2 text-[#5e4b35] hover:bg-[#f3ead7] font-serif transition-colors"
            >
              Settings
            </a>
          <% end %>
          
    <!-- Logout for all users -->
          <form action="/users/log-out" method="post" class="m-0">
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <input type="hidden" name="_method" value="delete" />
            <button
              type="submit"
              class="w-full text-left px-4 py-2 text-[#5e4b35] hover:bg-[#f3ead7] font-serif transition-colors border-t border-[#e8e0c5]"
            >
              Log out
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
