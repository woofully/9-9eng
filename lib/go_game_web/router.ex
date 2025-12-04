defmodule GoGameWeb.Router do
  use GoGameWeb, :router

  import GoGameWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GoGameWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # --- 1. ROOT ROUTE (Redirect to Lobby) ---
  scope "/", GoGameWeb do
    pipe_through :browser

    # We point root to the Lobby if logged in, or Login if not.
    # For now, let's just make it a redirect in the controller or use PageController
    get "/", PageController, :home
  end

  # --- 2. GUEST-ACCESSIBLE ROUTES (Lobby, Games) ---
  scope "/", GoGameWeb do
    pipe_through :browser

    live_session :guest_accessible,
      on_mount: [{GoGameWeb.UserAuth, :mount_current_scope}] do
      live "/lobby", LobbyLive.Index, :index
      live "/game/:id", GameLive.Show, :show
    end
  end

  # --- 3. AUTHENTICATED ROUTES (Settings - Registered Users Only) ---
  scope "/", GoGameWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GoGameWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    # Missing Route Restored:
    post "/users/update-password", UserSessionController, :update_password
  end

  # --- 4. PUBLIC AUTH ROUTES (Register, Login) ---
  scope "/", GoGameWeb do
    pipe_through [:browser]

    delete "/users/log-out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{GoGameWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
  end

  # --- 5. DEV TOOLS ---
  if Application.compile_env(:go_game, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GoGameWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
