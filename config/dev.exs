import Config

# config :logger, :default_formatter,
#   format: "$time $metadata[$level] $message\n",
#   metadata: [:file, :line]

config :logger,
  level: :debug,
  always_evaluate_messages: true

config :phoenix_container_example, PhoenixContainerExample.Repo,
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASS") || "postgres",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  database: System.get_env("DATABASE_DB") || "app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "BT+gHNLdPaMEECRy7B+/29ITdAzbbC7ispHszGDrcmaBiDCyeQ/07as6wsU8KJf/",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/phoenix_container_example_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :phoenix_container_example, dev_routes: true

# https://hexdocs.pm/opentelemetry_exporter/readme.html
if System.get_env("OTEL_DEBUG") == "true" do
  # Set via environment vars because server name is different in docker compose vs ECS:
  #   OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
  #   OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
  config :opentelemetry, :processors,
    otel_batch_processor: %{
      exporter: {:otel_exporter_stdout, []}
    }
else
  config :opentelemetry, traces_exporter: :none
end

# Initialize plugs at runtime for faster compilation
config :phoenix, :plug_init_mode, :runtime

# Set higher stacktrace during development.
# Avoid in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Include HEEx debug annotations as HTML comments in rendered markup
config :phoenix_live_view, debug_heex_annotations: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
