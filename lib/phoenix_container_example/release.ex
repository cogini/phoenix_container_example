defmodule PhoenixContainerExample.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  require Logger

  @app :phoenix_container_example

  @doc """
  Run database migrations.

  Equivalent to `mix ecto.migrate`.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      Logger.info("Running database migrations for #{inspect(repo)}")
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    load_app()
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  @doc """
  Create Ecto repo.

  Equivalent to `mix ecto.create`.
  """
  def create_repos do
    load_app()

    Enum.each(repos(), fn repo ->
      ensure_repo(repo)

      ensure_implements(
        repo.__adapter__,
        Ecto.Adapter.Storage,
        "create storage for #{inspect(repo)}"
      )

      case repo.__adapter__.storage_up(repo.config) do
        :ok ->
          Logger.info("Created database for #{inspect(repo)}")

        {:error, :already_up} ->
          Logger.info("Database exists for #{inspect(repo)}")

        {:error, term} when is_binary(term) ->
          Logger.error("Could not create database for #{inspect(repo)}: #{term}")

        {:error, term} ->
          Logger.error("Could not create database for #{inspect(repo)}: #{inspect(term)}")
      end
    end)
  end

  @doc """
  Run repo seeds to load data into database.

  Equivalent to running `mix run priv/repo/seeds.exs` on each database in the app.
  """
  def run_seeds(file \\ "seeds.exs") do
    load_app()

    for repo <- repos() do
      path = Path.join(repo_path(repo), file)

      if File.exists?(path) do
        Logger.info("Running #{inspect(repo)} seed #{path}")
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _ -> Code.require_file(path) end)
      end
    end
  end

  @doc """
  Run code in file.

  Equivalent to e.g. `mix run foo.exs`.
  """
  def run(path) do
    load_app()

    Code.require_file(path)
  end

  # @doc """
  # Evaluate code.
  # """
  # def eval_string(string, context \\ []) do
  #   load_app()
  #
  #   # result = Code.eval_string("a + b", [a: 1, b: 2], file: __ENV__.file, line: __ENV__.line)
  #   result = Code.eval_string(string, context, file: __ENV__.file, line: __ENV__.line)
  #   Logger.info("result: #{inspect(result)}")
  # end

  # Ensure module is an Ecto.Repo
  @spec ensure_repo(module()) :: Ecto.Repo.t()
  defp ensure_repo(repo) do
    case Code.ensure_compiled(repo) do
      {:module, _} ->
        if function_exported?(repo, :__adapter__, 0) do
          repo
        else
          raise "Module #{inspect(repo)} is not an Ecto.Repo"
        end

      {:error, error} ->
        raise "Could not load #{inspect(repo)}, error: #{inspect(error)}"
    end
  end

  # Ensure repo implements behaviour
  @spec ensure_implements(atom(), module(), String.t()) :: boolean()
  defp ensure_implements(module, behaviour, message) do
    all = Keyword.take(module.__info__(:attributes), [:behaviour])

    if [behaviour] not in Keyword.values(all) do
      raise "Expected #{inspect(module)} to implement #{inspect(behaviour)} to #{message}"
    end

    true
  end

  @doc """
  Get priv dir path for repository.
  """
  @spec repo_path(Ecto.Repo.t()) :: String.t()
  def repo_path(repo) do
    config = repo.config()
    priv = config[:priv] || "priv/#{repo |> Module.split() |> List.last() |> Macro.underscore()}"
    app = Keyword.fetch!(config, :otp_app)
    Application.app_dir(app, priv)
  end
end
