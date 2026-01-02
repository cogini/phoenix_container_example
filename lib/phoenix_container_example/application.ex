defmodule PhoenixContainerExample.Application do
  @moduledoc false

  use Application

  require Logger

  @app :phoenix_container_example

  @impl true
  def start(_type, _args) do
    # :opentelemetry_cowboy.setup()
    OpentelemetryBandit.setup()
    # OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryPhoenix.setup(adapter: :cowboy2)
    OpentelemetryLiveView.setup()
    OpentelemetryEcto.setup([@app, :repo])

    roles = Application.get_env(@app, :roles, [:app])
    Logger.info("Starting with roles: #{inspect(roles)}")

    # :recon_trace.calls([{:logger_formatter_json, :_, :_}, {:logger_h_common, :_, :_}, {:thoas, :_, :_}], {50, 1000})

    children =
      List.flatten([
        PhoenixContainerExampleWeb.Telemetry,
        PhoenixContainerExample.Repo,
        {DNSCluster, query: Application.get_env(@app, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: PhoenixContainerExample.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: PhoenixContainerExample.Finch},
        PhoenixContainerExampleWeb.Endpoint,
        cluster_supervisor()
      ])

    opts = [strategy: :one_for_one, name: PhoenixContainerExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp cluster_supervisor do
    topologies = Application.get_env(:libcluster, :topologies, [])

    if Enum.empty?(topologies) do
      []
    else
      [{Cluster.Supervisor, [topologies, [name: PhoenixContainerExample.ClusterSupervisor]]}]
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    PhoenixContainerExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
