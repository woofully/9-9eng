# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoGame is a Phoenix LiveView application for playing the board game Go (9x9 board). The application features real-time multiplayer gameplay, user authentication with magic link login, social features (friendships), and online presence tracking.

**Tech Stack:**
- Phoenix 1.8.2 with LiveView 1.1.0
- Elixir ~> 1.15
- PostgreSQL (via Ecto)
- Bandit web server
- Tailwind CSS + esbuild for assets
- Phoenix.Presence for real-time user tracking

## Development Commands

**Setup:**
```bash
mix setup                    # Install deps, setup DB, setup & build assets
```

**Running the app:**
```bash
mix phx.server              # Start server at localhost:4000
iex -S mix phx.server       # Start with IEx console
```

**Database:**
```bash
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Drop, recreate, and migrate
mix ecto.rollback           # Rollback last migration
```

**Testing:**
```bash
mix test                    # Run all tests (creates test DB automatically)
mix test path/to/file_test.exs                    # Run specific test file
mix test path/to/file_test.exs:42                 # Run test at specific line
```

**Assets:**
```bash
mix assets.setup            # Install Tailwind and esbuild
mix assets.build            # Compile assets
mix assets.deploy           # Minified production build
```

**Code Quality:**
```bash
mix precommit               # Run full precommit checks (compile with warnings-as-errors, unlock unused deps, format, test)
mix format                  # Format code
mix compile --warnings-as-errors
```

**Dev Tools:**
- LiveDashboard: http://localhost:4000/dev/dashboard
- Mailbox (Swoosh): http://localhost:4000/dev/mailbox

## Architecture

### Context-Based Organization

The application follows Phoenix contexts pattern with three main domains:

**GoGame.Accounts** (`lib/go_game/accounts.ex`)
- User registration, authentication, and session management
- Magic link authentication (passwordless login option)
- Email verification and password management
- "Sudo mode" for sensitive operations (20-minute authentication window)
- Scope-based access control (see config `:scopes` in `config/config.exs`)

**GoGame.Social** (`lib/go_game/social.ex`)
- Friend requests (pending/accepted states)
- Blocking users
- Friendship relationships (bidirectional queries)

**GoGame.Gameplay.Rules** (`lib/go_game/gameplay/rules.ex`)
- Pure functional core logic for 9x9 Go
- Move validation (bounds, empty intersection, suicide rule, ko rule)
- Capture detection using flood-fill algorithm
- Board state history for ko checking
- SGF export format support

### Web Layer Structure

**GoGameWeb** (`lib/go_game_web.ex`)
- Central module defining `use` macros for controllers, LiveView, LiveComponent, etc.
- All web modules should use `use GoGameWeb, :live_view` (or `:controller`, `:html`, etc.)
- Imports CoreComponents and Gettext via `html_helpers/0`
- Uses Phoenix.VerifiedRoutes (~p sigil) for route generation

**LiveView Pages:**
- `LobbyLive.Index`: Online presence tracking via Phoenix.Presence
- `GameLive.Show`: Game interface (uses board_renderer component)
- `UserLive.Registration`, `UserLive.Login`, `UserLive.Settings`: Auth flows

**Authentication:**
- `GoGameWeb.UserAuth` plug module handles authentication
- `:require_authenticated_user` pipeline for protected routes
- `on_mount: [{GoGameWeb.UserAuth, :ensure_authenticated}]` for LiveView sessions
- Scope-based authorization configured in `config/config.exs` under `:scopes`

### Real-time Features

**Phoenix.Presence** (`lib/go_game_web/channels/presence.ex`)
- Tracks online users in the lobby
- Subscribe to `"users:presence"` topic
- Presence.track/4 called in `LobbyLive.Index.mount/3`
- Handle `presence_diff` events to update online users list

**PubSub:** GoGame.PubSub (configured in Application supervisor)

### Database

**Ecto Repo:** `GoGame.Repo` (Postgres adapter)

**Key schemas:**
- `GoGame.Accounts.User`: email, hashed_password, confirmed_at, authenticated_at, username
- `GoGame.Accounts.UserToken`: session tokens, magic link tokens, email change tokens
- `GoGame.Social.Friendship`: requester_id, addressee_id, status (pending/accepted/blocked)

**Custom Repo methods:**
- `Repo.transact/1`: Wrapper for database transactions
- `Repo.all_by/2`: Fetch all records matching criteria

### Testing

- Uses ExUnit with Ecto.Adapters.SQL.Sandbox in `:manual` mode
- Test helper fixtures in `test/support/`
- ConnCase and DataCase for integration tests
- Test scope helper configured: `:register_and_log_in_user`

## Important Conventions

### Code Style
- Follow existing patterns in context modules (e.g., `Accounts`, `Social`)
- Use `with` statements for multi-step validations
- Pattern match on `{:ok, result}` and `{:error, reason}` tuples
- Pure functions in `Gameplay.Rules` module (no side effects)

### LiveView Patterns
- Always use `use GoGameWeb, :live_view` (never raw Phoenix.LiveView)
- Subscribe to PubSub topics in `mount/3` only when `connected?(socket)`
- Handle PubSub messages in `handle_info/2`
- Use `~p` sigil for route generation

### Authentication
- Access the current user via `socket.assigns.current_scope.user` in LiveViews (NOT `current_user`)
- Access the current user via `conn.assigns.current_scope.user` in Controllers
- Use `fetch_current_scope_for_user` plug in browser pipeline
- Respect sudo_mode/2 for sensitive operations (defaults to 20 minutes)

### Asset Pipeline
- JavaScript in `assets/js/`
- CSS in `assets/css/app.css` (Tailwind)
- Compiled to `priv/static/assets/`
- Use `mix assets.build` after modifying assets

### Migrations
- Always provide both up and down migrations
- Use timestamps (`:utc_datetime` type as per generators config)
- Migration files in `priv/repo/migrations/`

## Special Notes

- **GEMINI.md exists**: This codebase has guidance for the Gemini CLI agent. The core mandates apply here too: follow existing conventions, mimic code style, verify library usage before assuming availability.

- **Repo Extensions**: The Repo module has custom helper methods like `transact/1` and `all_by/2`. Check existing usage patterns before writing raw Ecto queries.

- **Scope System**: The application uses a scope-based authorization system configured in `config/config.exs`. The user scope is the default and uses `GoGame.Accounts.Scope`.
