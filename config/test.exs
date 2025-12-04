import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :go_game, GoGame.Repo,
  hostname: "ep-lucky-scene-a18pfrkh-pooler.ap-southeast-1.aws.neon.tech",
  database: "neondb",
  username: "neondb_owner",
  password: "npg_q2OWbxJfFml7",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ssl: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :go_game, GoGameWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "NvKe1phcTYX6Hy4VSAKCxQyCjEhHMeaBbL634JtPv/ivLThjp0mQroLsc9Yx4Btx",
  server: false

# In test we don't send emails
config :go_game, GoGame.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
