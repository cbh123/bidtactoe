import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :toe, Toe.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "toe_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :toe, ToeWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "l1sM+KK1o4FijjDQGw7aJAP9eMl0N+YmkdjIN+6cyazQ3dWEB4Zzbpm6oxhPtTEj",
  server: false

# In test we don't send emails.
config :toe, Toe.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
