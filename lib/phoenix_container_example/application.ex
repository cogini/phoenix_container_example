defmodule PhoenixContainerExample.Application do
  @moduledoc false

  use Application

  require Logger

  @app :phoenix_container_example

  @impl true
  def start(_type, _args) do
    OpentelemetryEcto.setup([@app, :repo])
    :opentelemetry_cowboy.setup()
    OpentelemetryPhoenix.setup(adapter: :cowboy2)
    OpentelemetryLiveView.setup()

    roles = Application.get_env(@app, :roles, [:app])
    Logger.info("Starting with roles: #{inspect(roles)}")

    children =
      List.flatten([
        PhoenixContainerExampleWeb.Telemetry,
        PhoenixContainerExample.Repo,
        {DNSCluster, query: Application.get_env(:phoenix_container_example, :dns_cluster_query) || :ignore},
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

    if length(topologies) > 0 do
      [{Cluster.Supervisor, [topologies, [name: PhoenixContainerExample.ClusterSupervisor]]}]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixContainerExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
