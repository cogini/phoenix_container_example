defmodule PhoenixContainerExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_container_example,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: [
        # plt_add_deps: :project,
        plt_add_apps: [:mix, :ex_unit]
        # plt_add_deps: true,
        # flags: ["-Werror_handling", "-Wrace_conditions"],
        # flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs],
        # ignore_warnings: "dialyzer.ignore-warnings"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        quality: :test,
        "quality.ci": :test,
        "assets.deploy": :prod,
        deploy: :prod
      ],
      default_release: :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {PhoenixContainerExample.Application, []},
      extra_applications:
        [:logger, :runtime_tools, :eex] ++
          extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:dev), do: [:tools]
  defp extra_applications(:test), do: [:tools]
  defp extra_applications(_), do: []

  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp releases do
    [
      prod: [
        reboot_system_after_config: true,
        include_executables_for: [:unix],
        # Don't need to tar if we are just going to copy it
        steps: [:assemble, :tar],
        applications: [opentelemetry_exporter: :permanent, opentelemetry: :temporary]
      ]
    ]
  end

  defp deps do
    [
      {:appsignal_phoenix, "~> 2.0"},
      # {:appsignal, "~> 2.0"},
      {:aws_rds_castore, "~> 1.1"},
      {:bandit, "~> 1.0"},
      {:castore, "~> 1.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.10"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.5"},
      {:excoveralls, "~> 0.18.0", only: [:dev, :test], runtime: false},
      {:finch, "~> 0.14"},
      {:floki, ">= 0.30.0", only: :test},
      {:gen_smtp, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:hackney, "~> 1.9"},
      {:jason, "~> 1.2"},
      {:junit_formatter, "~> 3.3", only: [:dev, :test], runtime: false},
      # {:libcluster_ecs, github: "pro-football-focus/libcluster_ecs"},
      {:kubernetes_health_check, github: "cogini/kubernetes_health_check"},
      # {:kubernetes_health_check, "~> 0.7.0"},
      # {:logger_formatter_json, "~> 0.8.0"},
      {:logger_formatter_json, github: "cogini/logger_formatter_json"},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:observer_cli, "~> 1.7"},
      # tls_certificate_check needs to be started before opentelemetry_exporter
      {:tls_certificate_check, "~> 1.13"},
      # opentelemetry_exporter needs to be started before the other opentelemetry modules
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_ecto, "~> 1.0"},
      # {:opentelemetry_logger_metadata, "~> 0.1.0"},
      # {:opentelemetry_cowboy, "~> 1.0"},
      {:opentelemetry_bandit, "~> 0.2.0"},
      {:opentelemetry_liveview, "~> 1.0.0-rc.4"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_telemetry, "~> 1.1", override: true},
      {:opentelemetry_xray, "~> 0.7.0"},
      # {:opentelemetry_xray, github: "cogini/opentelemetry_xray"},
      # {:opentelemetry_xray, path: "../../opentelemetry_xray", override: true},
      {:phoenix, "~> 1.7.11"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      # {:plug_cowboy, "~> 2.5"},
      {:plugsnag, "~> 1.7"},
      {:postgrex, ">= 0.0.0"},
      {:recon, "~> 2.5"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:ssl_verify_fun, "~> 1.1"},
      {:styler, "~> 1.4.0", only: [:dev, :test], runtime: false},
      {:sweet_xml, "~> 0.6"},
      {:swoosh, "~> 1.5"},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      # {:telemetry_metrics_statsd, "~> 0.6.2"},
      {:telemetry_poller, "~> 1.0"},
      {:uinta, "~> 0.15.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      quality: [
        "format --check-formatted",
        "credo",
        # "credo --mute-exit-status",
        # mix deps.clean --unlock --unused
        "deps.unlock --check-unused",
        # mix deps.update
        # "hex.outdated",
        # "hex.audit",
        "deps.audit",
        "sobelow --exit --quiet --skip -i DOS.StringToAtom,Config.HTTPS,Config.HSTS",
        "dialyzer --quiet-with-result"
      ],
      "quality.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        # "hex.outdated",
        "hex.audit",
        "deps.audit",
        "credo",
        "sobelow --exit --quiet --skip -i DOS.StringToAtom,Config.HTTPS,Config.HSTS",
        "dialyzer --quiet-with-result"
      ]
    ]
  end
end
