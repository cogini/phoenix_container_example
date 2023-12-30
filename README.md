# phoenix_container_example

## Installation

Install [direnv](https://direnv.net/)

```console
brew install direnv
```

Create `.direnv` file in project root:

```shell
# Run Phoenix server by default
export PHX_SERVER=true

# Set default file for docker compose
export COMPOSE_FILE=docker-compose.gha.yml

# Connect to database on local machine
# export DATABASE_URL=ecto://postgres:postgres@localhost/app
# Connect to database running in container
export DATABASE_URL=ecto://postgres:postgres@postgres/app
# export SECRET_KEY_BASE="XXX"

# Override log level
# export LOG_LEVEL=debug

# Run OpenTelemetry in dev and test
# export OTEL_DEBUG=true
# export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
# export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
```

Create `postgres` user in local database with password `postgres`:

```console
createuser --createdb --encrypted --pwprompt postgres
```

Install and set up dependencies:

```console
mix setup
```

Start Phoenix server:

```console
iex -S mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
