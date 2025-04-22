import Config

config :phoenix_container_example, PhoenixContainerExample.Repo,
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASS") || "postgres",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  database: System.get_env("DATABASE_DB") || "app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "J6m9FJr/W+/oYmYQsRDIKWS3ZpCZGN9Xd/JP6qMvMzViO866jkg0lAZB/4yZjkCT",
  server: false

config :junit_formatter,
  report_dir: "#{Mix.Project.build_path()}/junit-reports",
  automatic_create_dir?: true,
  # print_report_file: true,
  # prepend_project_name?: true,
  include_filename?: true,
  include_file_line?: true

config :logger,
  level: :warning,
  always_evaluate_messages: true

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:file, :line]

if System.get_env("OTEL_DEBUG") == "true" do
  config :opentelemetry, :processors,
    otel_batch_processor: %{
      exporter: {:otel_exporter_stdout, []}
    }
else
  config :opentelemetry, traces_exporter: :none
end

# In test we don't send emails.
config :phoenix_container_example, PhoenixContainerExample.Mailer, adapter: Swoosh.Adapters.Test

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
