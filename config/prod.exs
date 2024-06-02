import Config

config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :phoenix_container_example, Uinta.Plug, format: :map
# Include GraphQL variables in log line
# include_variables: true,
# ignored_paths: [],
# filter_variables: [],
# success_log_sampling_ratio: 1.0,
# include_datadog_fields: false

config :logger, level: :info, utc_log: true

config :logger, :default_handler,
  filters: [
    # Elixir default filter
    remote_gl: {&:logger_filters.remote_gl/2, :stop},
    # Format trace_id for X-Ray
    opentelemetry_trace_id: {&:opentelemetry_xray_logger_filter.trace_id/2, %{}}
  ],
  formatter: {
    :logger_formatter_json,
    %{
      template: [
        :msg,
        # :time,
        :level,
        :file,
        :line,
        # :mfa,
        :pid,
        :request_id,
        :otel_trace_id,
        :otel_span_id,
        :otel_trace_flags,
        :xray_trace_id,
        :rest
      ]
    }
  }

# https://hexdocs.pm/opentelemetry_exporter/readme.html
# Set via environment vars because server name is different in docker compose vs ECS:
#   OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
#   OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
#
# config :opentelemetry, :processors,
# otel_batch_processor: %{
#   exporter: {
#     :opentelemetry_exporter,
#     %{
#       protocol: :grpc,
#       endpoints: [
#         # gRPC
#         ~c"http://localhost:4317"
#         # HTTP
#         # 'http://localhost:4318'
#         # 'http://localhost:55681'
#         # {:http, 'localhost', 4318, []}
#       ]
#       # headers: [{"x-honeycomb-dataset", "experiments"}]
#     }
#   }
# }

# Because we are doing containerized testing, default to same settings as test env.
# Prod settings are handled in runtime.exs if we are actually running in prod.
config :phoenix_container_example, PhoenixContainerExample.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false

# Configures Swoosh API Client
# config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: PhoenixContainerExample.Finch

# Disable Swoosh Local Memory Storage
# config :swoosh, local: false

# config :tzdata, :data_dir, "/var/lib/tzdata"

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
