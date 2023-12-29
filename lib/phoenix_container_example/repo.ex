defmodule PhoenixContainerExample.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_container_example,
    adapter: Ecto.Adapters.Postgres
end
