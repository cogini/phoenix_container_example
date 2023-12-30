defmodule PhoenixContainerExampleWeb.HealthPlug do
  @moduledoc """
  Return app status for health checks.

  It implements checks for Kubernetes.

  * https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
  * https://shyr.io/blog/kubernetes-health-probes-elixir

  Following is an example Kubernetes deployment yaml configuration:

  ```yaml
    startupProbe:
      httpGet:
        path: /healthz/startup
        port: http
      periodSeconds: 3
      failureThreshold: 5

    livenessProbe:
      httpGet:
        path: /healthz/liveness
        port: http
      periodSeconds: 10
      failureThreshold: 6

    readinessProbe:
      httpGet:
        path: /healthz/readiness
        port: http
      periodSeconds: 10
      failureThreshold: 1
    ```
  """
  import Plug.Conn

  alias PhoenixContainerExample.Health

  require Logger

  def init(opts), do: opts

  # Basic health check.
  def call(%Plug.Conn{request_path: "/healthz"} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "OK")
    |> halt()

    # case Health.liveness() do
    #   :ok ->
    #     conn
    #     |> put_resp_content_type("text/plain")
    #     |> send_resp(200, "OK")
    #     |> halt()
    #
    #   {:error, reason} ->
    #     Logger.error("#{inspect(reason)}")
    #
    #     send_resp(conn, 503, inspect(reason))
    #     |> halt()
    # end
  end

  # Return status for Kubernetes startupProbe.
  def call(%Plug.Conn{request_path: "/healthz/startup"} = conn, _opts) do
    case Health.startup() do
      :ok ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "OK")
        |> halt()

      # {:error, {status_code, reason}} when is_integer(status_code) ->
      #   Logger.error("#{inspect(reason)}")
      #   send_resp(conn, status_code, inspect(reason))
      #   |> halt()

      {:error, reason} ->
        Logger.error("#{inspect(reason)}")

        conn
        |> send_resp(503, inspect(reason))
        |> halt()
    end
  end

  # Return status for Kubernetes livenessProbe.
  def call(%Plug.Conn{request_path: "/healthz/liveness"} = conn, _opts) do
    case Health.liveness() do
      :ok ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "OK")
        |> halt()

      # {:error, {status_code, reason}} when is_integer(status_code) ->
      #   Logger.error("#{inspect(reason)}")
      #   send_resp(conn, status_code, inspect(reason))
      #   |> halt()

      {:error, reason} ->
        Logger.error("#{inspect(reason)}")

        conn
        |> send_resp(503, inspect(reason))
        |> halt()
    end
  end

  # Return status for Kubernetes readinessProbe.
  def call(%Plug.Conn{request_path: "/healthz/readiness"} = conn, _opts) do
    case Health.readiness() do
      :ok ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "OK")
        |> halt()

      # {:error, {status_code, reason}} when is_integer(status_code) ->
      #   Logger.error("#{inspect(reason)}")
      #   send_resp(conn, status_code, inspect(reason))
      #   |> halt()

      {:error, reason} ->
        Logger.error("#{inspect(reason)}")

        conn
        |> send_resp(503, inspect(reason))
        |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
