import Config

alias Elixir.Cluster.Strategy.DNSPoll
alias PhoenixContainerExample.Config.Endpoint, as: EndpointConfig

roles = (System.get_env("ROLES") || "app") |> String.split(",") |> Enum.map(&String.to_atom/1)
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
  # {"FOO", :phoenix_container_example, :foo},
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
  region: System.get_env("AWS_REGION") || "us-east-1"

if config_env() == :dev do
  # host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

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
          "HTTPS_KEYFILE" => :keyfile,
          "HTTPS_PORT" => :port
        },
        cipher_suite: :strong,
        log_level: :warning
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
  maybe_ecto_log = System.get_env("ECTO_LOG") in ~w(true 1)

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :phoenix_container_example, PhoenixContainerExample.Repo,
    ssl: maybe_ecto_ssl,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    log: maybe_ecto_log,
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
    # https:
    #   EndpointConfig.https_opts(
    #     System.get_env(),
    #     %{
    #       "HTTPS_CACERTS" => :cacerts,
    #       "HTTPS_CACERTFILE" => :cacertfile,
    #       "HTTPS_CERT" => :cert,
    #       "HTTPS_CERTFILE" => :certfile,
    #       # "HTTPS_CIPHER_SUITE" => :cipher_suite,
    #       "HTTPS_KEY" => :key,
    #       "HTTPS_KEYFILE" => :keyfile,
    #       "HTTPS_PORT" => :port
    #     },
    #     cipher_suite: :strong,
    #     log_level: :warning
    #   ),
    secret_key_base: secret_key_base

  config :phoenix_container_example, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :phoenix_container_example, PhoenixContainerExample.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

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
      # Local testing with docker compose
      # Use multicast UDP to form a cluster between nodes gossiping a heartbeat
      # This does not work inside ECS
      config :libcluster,
        topologies: [
          app: [
            strategy: Cluster.Strategy.Gossip
          ]
        ]

    "local" ->
      # Use epmd to connect to discovered nodes on the local host
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
