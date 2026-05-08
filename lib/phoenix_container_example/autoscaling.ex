defmodule PhoenixContainerExample.Autoscaling do
  @moduledoc """
  Manage AWS Application Auto Scaling
  <https://docs.aws.amazon.com/autoscaling/application/APIReference/API_RegisterScalableTarget.html>
  """
  use GenServer

  alias ExAws.Operation.JSON
  alias PhoenixContainerExample.RateLimit

  require Logger

  @tab :aws_autoscaling
  @default_duration to_timeout(minute: 5)

  # Public API

  @doc "Register events and corresponding targets."
  @spec register_events(list(map()), keyword()) :: :ok
  def register_events(events, opts \\ []) do
    tab = opts[:tab] || @tab

    for {event_name, targets} <- events do
      true = :ets.insert(tab, {event_name, targets})
    end

    :ok
  end

  @doc "Trigger event, updating associated target(s)"
  @spec trigger_event(atom) :: :ok | {:error, :unknown_event | :rate_limit | term()}
  def trigger_event(event_name, opts \\ []) do
    Logger.debug("event: #{event_name}")

    with {:ok, events} <- lookup_event(event_name, opts),
         event = events,
         aws_data = map_keys(event),
         {:ok, data} <- rate_limit(aws_data, opts) do
      :ok = aws_request(request_data)
      :ok
    end
  end

  # Look up event in ETS
  @spec lookup_event(term(), keyword()) :: {:ok, list(map())} | {:error, :unknown_event}
  defp lookup_event(event_name, opts) do
    tab = opts[:tab]

    case :ets.lookup(tab, event_name) do
      [{^event_name, events}] ->
        {:ok, events}

      [] ->
        {:error, :unknown_event}
    end
  end

  # Convert Elixir-style keys in the config to PascalCase format AWS expects.
  @spec map_keys(map()) :: map()
  defp map_keys(data) do
    for {key, value} <- data, into: %{} do
      camel_key = key |> to_string() |> Macro.camelize()
      {camel_key, value}
    end
  end

  @spec rate_limit(map(), keyword()) :: {:ok, map()} | {:error, :rate_limit}
  defp rate_limit(event, opts) do
    rate_limit = opts[:rate_limit] || RateLimit

    resource_id = Map.fetch!(event, :resource_id)
    {duration, event} = Map.pop(event, :backoff_duration, @default_duration)

    case rate_limit.hit(resource_id, duration, 1) do
      {:allow, _count} ->
        {:ok, event}

      {:deny, retry_after} ->
        Logger.debug("Rate limit #{resource_id}. Retry after: #{retry_after}ms")
        {:error, :rate_limit}
    end
  end

  @doc "Make AWS RegisterScalableTarget request."
  @spec aws_request(map()) :: :ok | {:error, String.t()}
  def aws_request(data) do
    result =
      data
      |> to_operation()
      |> ExAws.request()

    case result do
      {:ok, response} ->
        Logger.debug("AWS: RegisterScalableTarget #{inspect(data)}: #{inspect(response)}")
        :ok

      {:error, error} ->
        message = "AWS: RegisterScalableTarget #{inspect(data)}: #{inspect(error)}"
        Logger.debug(message)
        {:error, message}
    end
  end

  @doc "Create ExAws Operation from data."
  @spec to_operation(map()) :: JSON.t()
  # https://github.com/aws/aws-sdk-go/tree/main/models/apis/application-autoscaling/2016-02-06
  # {
  #    "MaxCapacity": number,
  #    "MinCapacity": number,
  #    "ResourceId": "string",
  #    "RoleARN": "string",
  #    "ScalableDimension": "string",
  #    "ServiceNamespace": "string",
  #    "SuspendedState": { 
  #       "DynamicScalingInSuspended": boolean,
  #       "DynamicScalingOutSuspended": boolean,
  #       "ScheduledScalingSuspended": boolean
  #    },
  #    "Tags": { 
  #       "string" : "string" 
  #    }
  # }
  def to_operation(data) do
    %JSON{
      http_method: :post,
      service: "application-autoscaling",
      headers: [
        {"x-amz-target", "AnyScaleFrontendService.RegisterScalableTarget"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: data
    }
  end

  # GenServer
  # At this point, the only purpose of the GenServer is to manage the ETS table lifecycle.

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(arg) do
    name = Keyword.get(arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, arg, name: name)
  end

  @impl true
  def init(args) do
    Logger.debug("init: #{__MODULE__} args: #{inspect(args)}")

    defaults = [
      tab: @tab,
      rate_limit: RateLimit
    ]

    opts = Keyword.merge(defaults, args)
    tab = opts[:tab]

    ^tab = :ets.new(tab, [:set, :public, :named_table, {:read_concurrency, true}])

    config = args[:config] || []
    events = config[:events] || []

    register_events(events, opts)

    {:ok, opts}
  end

  @impl true
  def terminate(reason, state) do
    tab = state[:tab]
    Logger.debug("terminate: #{__MODULE__} reason #{inspect(reason)}")
    :ets.delete(tab)
  end
end
