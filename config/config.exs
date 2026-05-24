import Config

config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:file, :line, :request_id, :otel_trace_id, :otel_span_id, :xray_trace_id]

config :logger,
  level: :info

config :mix_deploy,
  release_name: Mix.env(),
  base_dir: "/opt/foo",
  sudo_deploy: true,
  sudo_app: true,
  dirs: [
    # App runtime files which may be deleted between runs, /run/#{ext_name}
    :runtime,
    # Used for RELEASE_TMP, RELEASE_MUTABLE_DIR, runtime-environment
    # App configuration, e.g. db passwords, /etc/#{ext_name}
    :configuration,
    # App data or state persisted between runs, /var/lib/#{ext_name}
    :state,
    # App cache files which can be deleted, /var/cache/#{ext_name}
    :cache,
    # App external log files, not via journald, /var/log/#{ext_name}
    # :logs,
    # App temp files, /var/tmp/#{ext_name}
    :tmp
  ],
  # This should match mix_systemd
  env_vars: [
    # Tell release scripts to use runtime directory for temp files
    ["RELEASE_TMP=", :runtime_dir],
    "HOME=/home/foo"
  ],
  # create_dirs: [
  #   # /opt/log-receiver/etc
  #   %{
  #     path: [:deploy_dir, "/etc"],
  #     user: "$DEPLOY_USER",
  #     group: "$APP_GROUP",
  #     mode: "750"
  #   }
  # ],
  # When deploying, copy config/environment to /etc/log-receiver/environment
  # copy_files: [
  #   %{
  #     src: "config/environment",
  #     dst: [:deploy_dir, "/etc/environment"],
  #     user: "$DEPLOY_USER",
  #     group: "$APP_GROUP",
  #     mode: "640"
  #   }
  # ],
  # Generate these scripts in bin
  templates: [
    # Systemd wrappers
    "start",
    "stop",
    "restart",
    "enable",

    # System setup
    "create-users",
    "create-dirs",
    "set-perms",

    # Local deploy
    "init-local",
    "copy-files",
    "release",
    "rollback",

    # CodeDeploy
    "clean-target",
    "extract-release",
    # "migrate",

    # CodeBuild
    "stage-files",
    # "sync-assets-s3",

    # Release commands
    "set-env",
    "remote-console",
    "migrate"

    # Runtime environment
    # "sync-config-s3",
    # "runtime-environment-file",
    # "runtime-environment-wrap",
    # "set-cookie-ssm",
  ],
  app_user: "foo",
  app_group: "foo",
  deploy_user: "deploy",
  deploy_group: "deploy",
  systemd_version: 219

config :mix_systemd,
  release_name: Mix.env(),
  base_dir: "/opt/foo",
  dirs: [
    # App runtime files which may be deleted between runs, /run/#{ext_name}
    :runtime,
    # Used for RELEASE_TMP, RELEASE_MUTABLE_DIR, runtime-environment
    # App configuration, e.g. db passwords, /etc/#{ext_name}
    :configuration,
    # App data or state persisted between runs, /var/lib/#{ext_name}
    :state,
    # App cache files which can be deleted, /var/cache/#{ext_name}
    :cache,
    # App external log files, not via journald, /var/log/#{ext_name}
    # :logs,
    # App temp files, /var/tmp/#{ext_name}
    :tmp
  ],
  runtime_directory_preserve: "yes",
  env_vars: [
    # Tell release scripts to use runtime directory for temp files
    ["RELEASE_TMP=", :runtime_dir],
    "HOME=/home/foo"
  ],
  env_files: [
    # Read environment vars from the file /etc/foo/environment, if present
    ["-", :configuration_dir, "/environment"],
    # Read environment vars from the file /etc/foo/environment.local, if present
    ["-", :configuration_dir, "/environment.local"],
    # Read environment vars from file /opt/foo/etc/environment
    ["-", :deploy_dir, "/etc/environment"]
  ],
  exec_start: [
    [:current_dir, "/bin/start-systemd"]
  ],
  # exec_start_pre: [
  #   # Run before starting the app
  #   # `!` means the script is run as root, not as the app user
  #   # ["!", :deploy_dir, "/bin/deploy-sync-config-s3"]
  #   # ExecStart=<%= "#{exec_start_wrap}#{current_dir}/bin/#{release_name} #{start_command}" %>
  #   [:current_dir, "/bin/", :release_name, " eval ", :module_name, ".Release.create_repos()"],
  #   [:current_dir, "/bin/", :release_name, " eval ", :module_name, ".Release.migrate()"]
  # ],
  exec_stop: [
    [:current_dir, "/bin/stop-systemd"]
  ],
  # limit_nofile: nil,
  # limit_core: "infinity",
  # Run app under this OS user, default is name of app
  app_user: "foo",
  app_group: "foo",
  systemd_version: 219

# https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/
config :opentelemetry, :resource, [
  # In production, set from OTEL_SERVICE_NAME or Erlang release name OS env var
  {"service.name", to_string(Mix.Project.config()[:app])},
  # {"service.namespace", "MyNamespace"},
  {"service.version", Mix.Project.config()[:version]}
]

config :opentelemetry,
  id_generator: :opentelemetry_xray_id_generator,
  propagators: [:opentelemetry_xray_propagator, :baggage]

config :phoenix, :json_library, Jason

# Disable Phoenix request logging in favor of Uinta
# config :phoenix, logger: false

config :phoenix_container_example, PhoenixContainerExample.Mailer, adapter: Swoosh.Adapters.Local

config :phoenix_container_example, PhoenixContainerExampleWeb.Endpoint,
  url: [host: "localhost"],
  # adapter: Phoenix.Endpoint.Cowboy2Adapter,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [
      html: PhoenixContainerExampleWeb.ErrorHTML,
      json: PhoenixContainerExampleWeb.ErrorJSON
    ],
    layout: false
  ],
  pubsub_server: PhoenixContainerExample.PubSub,
  live_view: [signing_salt: "Mywi6aA5"]

config :phoenix_container_example,
  ecto_repos: [PhoenixContainerExample.Repo],
  generators: [timestamp_type: :utc_datetime]

config :phoenix_container_example,
  foo: "default"

config :tailwind,
  version: "3.4.3",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :tzdata, :autoupdate, :disabled

import_config "#{config_env()}.exs"
