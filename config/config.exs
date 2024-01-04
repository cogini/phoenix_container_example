import Config

config :phoenix_container_example,
  ecto_repos: [PhoenixContainerExample.Repo],
  generators: [timestamp_type: :utc_datetime]

config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [
      html: PhoenixContainerExampleWeb.ErrorHTML,
      json: PhoenixContainerExampleWeb.ErrorJSON
    ],
    layout: false
  ],
  pubsub_server: PhoenixContainerExample.PubSub,
  live_view: [signing_salt: "Mywi6aA5"]

config :phoenix_container_example, PhoenixContainerExample.Mailer, adapter: Swoosh.Adapters.Local

config :phoenix_container_example,
  foo: "default"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger,
  level: :info

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  # metadata: [:file, :line, :request_id, :otel_trace_id, :otel_span_id, :xray_trace_id]
  metadata: [:file, :line, :request_id]

config :opentelemetry,
  id_generator: :opentelemetry_xray_id_generator,
  propagators: [:opentelemetry_xray_propagator, :baggage]

# resource_detectors: [:otel_resource_env_var, :otel_resource_app_env]

# https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/
config :opentelemetry, :resource, [
  # In production, set from OTEL_SERVICE_NAME or Erlang release name OS env var
  {"service.name", to_string(Mix.Project.config()[:app])},
  # {"service.namespace", "MyNamespace"},
  {"service.version", Mix.Project.config()[:version]}
]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Disable normal Phoenix.Logger, as we are using uinta
# https://github.com/podium/uinta
config :phoenix, logger: false

import_config "#{config_env()}.exs"
