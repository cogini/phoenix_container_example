defmodule PhoenixContainerExample.Autoscaling do
  @moduledoc """
  Manage AWS Application Auto Scaling
  <https://docs.aws.amazon.com/autoscaling/application/APIReference/API_RegisterScalableTarget.html>
  """
  use GenServer

  alias ExAws.Operation.JSON

  require Logger

  @tab :aws_autoscaling
  @default_backoff_duration to_timeout(minute: 5)

  # Public API

  @spec register_events(list) :: :ok
  def register_events(events) do
    for {event_name, event_definitions} <- events do
      for event_definition <- event_definitions do
        true = :ets.insert(@tab, {event_name, event_definition})
      end
    end

    :ok
  end

  @spec trigger_event(atom) :: :ok | {:error, :unknown_event | :rate_limit | term()}
  def trigger_event(event_name) do
    case :ets.lookup(@tab, event_name) do
      [{^event_name, event_definition}] ->
        Logger.debug("Triggering event: #{event_name} with definition: #{inspect(event_definition)}")

        resource_id = Map.fetch!(event_definition, :resource_id)

        {backoff_duration, api_data} =
          Map.pop(event_definition, :backoff_duration, @default_backoff_duration)

        case PhoenixContainerExample.RateLimit.hit(resource_id, backoff_duration, 1) do
          {:allow, _count} ->
            aws_request(api_data)

          {:deny, retry_after} ->
            Logger.debug("Rate limit #{resource_id}. Retry after: #{retry_after}ms")
            {:error, :rate_limit}
        end

      [] ->
        Logger.debug("Event not found: #{event_name}")
        {:error, :unknown_event}
    end
  end

  # Utils

  @doc "Make AWS RegisterScalableTarget request."
  @spec aws_request(map()) :: :ok | {:error, String.t}
  def aws_request(data) do
    result =
      data
      |> map_keys()
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

  @doc "Create ExAws operation."
  @spec to_operation(map) :: JSON.t()
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

  # Convert Elixir-style keys in the config to AWS expected PascalCase format.
  defp map_keys(data) do
    for {key, value} <- data, into: %{} do
      camel_key = key |> to_string() |> Macro.camelize()
      {camel_key, value}
    end
  end

  # GenServer
  # At this point, the only purpose of the GenServer is to manage the ETS table lifecycle.

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(arg) do
    Logger.debug("init: #{__MODULE__} arg: #{inspect(arg)}")

    @tab = :ets.new(@tab, [:set, :public, :named_table, {:read_concurrency, true}])

    config = arg
    events = config[:events] || []
    PhoenixContainerExample.Autoscaling.register_events(events)

    {:ok, arg}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.debug("terminate: #{__MODULE__} reason #{inspect(reason)}")
    :ets.delete(@tab)
  end
end
