import Config

alias Elixir.Cluster.Strategy.DNSPoll
alias PhoenixContainerExample.Config.Endpoint, as: EndpointConfig

roles = "ROLES" |> System.get_env("app") |> String.split(",") |> Enum.map(&String.to_atom/1)
config :phoenix_container_example, roles: roles

if System.get_env("PHX_SERVER") && :app in roles do
  config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint, server: true
end

# Allow log level to be set at runtime
if config_env() != :test and System.get_env("LOG_LEVEL") do
  config :logger,
    level: String.to_existing_atom(System.get_env("LOG_LEVEL"))
end

# Optionally set values from OS environment vars
env_config = [
  {"BUGSNAG_API_KEY", :bugsnag, :api_key},
  {"BUGSNAG_APP_VERSION", :bugsnag, :app_version},
  {"BUGSNAG_RELEASE_STAGE", :bugsnag, :release_stage}
]

for {env, app, key} <- env_config, value = System.get_env(env) do
  config(app, [{key, value}])
end

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: System.get_env("AWS_REGION", "us-east-1")

if config_env() == :dev do
  # host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT", "4000"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
    # url: [host: host, port: 443, scheme: "https"],
    # static_url: [host: "assets." <> host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      # ip: {0, 0, 0, 0, 0, 0, 0, 0},
      ip: {0, 0, 0, 0},
      port: port
    ],
    https:
      EndpointConfig.https_opts(
        System.get_env(),
        %{
          "HTTPS_CACERTS" => :cacerts,
          "HTTPS_CACERTFILE" => :cacertfile,
          "HTTPS_CERT" => :cert,
          "HTTPS_CERTFILE" => :certfile,
          # "HTTPS_CIPHER_SUITE" => :cipher_suite,
          "HTTPS_KEY" => :key,
          "HTTPS_KEYFILE" => :keyfile
          # "HTTPS_PORT" => :port
        },
        # adapter: Bandit.PhoenixAdapter,
        # adapter: Phoenix.Endpoint.Cowboy2Adapter
        port: String.to_integer(System.get_env("HTTPS_PORT", "4443")),
        cipher_suite: :strong
        # log_level: :warning
      ),
    secret_key_base: secret_key_base
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ecto_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
  maybe_ecto_ssl = System.get_env("ECTO_SSL") in ~w(true 1)
  # Logger log level for query. Can be any of Logger.level/0 values or false
  ecto_log = System.get_env("ECTO_LOG") || false

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST", "example.com")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :phoenix_container_example, PhoenixContainerExample.Repo,
    ssl: maybe_ecto_ssl,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    log: ecto_log,
    # timeout: 20_000,
    # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html
    ssl_opts: AwsRdsCAStore.ssl_opts(database_url),
    socket_options: maybe_ecto_ipv6

  config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    # static_url: [host: "assets." <> host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      # ip: {0, 0, 0, 0, 0, 0, 0, 0},
      ip: {0, 0, 0, 0},
      port: port
    ],
    https:
      EndpointConfig.https_opts(
        System.get_env(),
        %{
          "HTTPS_CACERTS" => :cacerts,
          "HTTPS_CACERTFILE" => :cacertfile,
          "HTTPS_CERT" => :cert,
          "HTTPS_CERTFILE" => :certfile,
          # "HTTPS_CIPHER_SUITE" => :cipher_suite,
          "HTTPS_KEY" => :key,
          "HTTPS_KEYFILE" => :keyfile
          # "HTTPS_PORT" => :port
        },
        port: String.to_integer(System.get_env("HTTPS_PORT", "4443")),
        cipher_suite: :stron,
        log_level: :warning,
        adapter: Phoenix.Endpoint.Cowboy2Adapter
      ),
    secret_key_base: secret_key_base

  config :phoenix_container_example, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Only configure the production mailer if we have AWS credentials
  if System.get_env("AWS_ACCESS_KEY_ID") || System.get_env("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI") do
    config :phoenix_container_example, PhoenixContainerExample.Mailer, adapter: Swoosh.Adapters.ExAwsAmazonSES

    config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: PhoenixContainerExample.Finch
    # Disable Swoosh Local Memory Storage
    config :swoosh, local: false
  end

  config :libcluster, debug: true

  # https://dmblake.com/elixir-clustering-with-libcluster-and-aws-ecs-fargate-in-cdk
  case System.get_env("LIBCLUSTER_STRATEGY", "none") do
    "none" ->
      config :libcluster, topologies: []

    "gossip" ->
      # Use multicast UDP to form a cluster between nodes gossiping a heartbeat
      # Used for local testing with docker compose. It does not work inside ECS.
      config :libcluster,
        topologies: [
          app: [
            strategy: Cluster.Strategy.Gossip
          ]
        ]

    "local" ->
      # Use epmd to connect to discover nodes on local host
      config :libcluster,
        topologies: [
          app: [
            strategy: Cluster.Strategy.LocalEPMD
          ]
        ]

    "dns" ->
      # Periodically poll DNS to find nodes.
      # This uses AWS Service Discovery support for ECS.
      # https://hexdocs.pm/libcluster/Cluster.Strategy.DNSPoll.html
      # Assumes nodes respond to DNS query (A record) and node name
      # pattern of <name>@<ip-address>.
      config :libcluster,
        topologies: [
          app: [
            strategy: DNSPoll,
            config: [
              # name of nodes before the IP address (required)
              node_basename: "prod",
              # DNS query to find nodes (required)
              query: "foo-app.foo.internal"
              # How often to poll in ms
              # polling_interval: 5_000,
            ]
          ],
          worker: [
            strategy: DNSPoll,
            config: [
              # name of nodes before the IP address (required)
              node_basename: "prod",
              # DNS query to find nodes (required)
              query: "foo-worker.foo.internal"
              # How often to poll in ms
              # polling_interval: 5_000,
            ]
          ]
        ]
  end
end
