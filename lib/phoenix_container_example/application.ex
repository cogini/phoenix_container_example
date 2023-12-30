defmodule PhoenixContainerExample.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhoenixContainerExampleWeb.Telemetry,
      PhoenixContainerExample.Repo,
      {DNSCluster, query: Application.get_env(:phoenix_container_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhoenixContainerExample.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: PhoenixContainerExample.Finch},
      # Start a worker by calling: PhoenixContainerExample.Worker.start_link(arg)
      # {PhoenixContainerExample.Worker, arg},
      # Start to serve requests, typically the last entry
      PhoenixContainerExampleWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixContainerExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixContainerExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
