defmodule PhoenixContainerExample.Config.Endpoint do
  @moduledoc """
  Utility functions for configuring endpoint.
  """

  require Logger

  @doc "Get https options from OS environment."
  @spec https_opts(map(), map(), keyword()) :: keyword() | false
  def https_opts(env, names, default_opts \\ []) do
    opts =
      for {name, value} <- env, not empty?(value), key = names[name], into: [] do
        {key, convert_opt(key, value)}
      end

    result = Keyword.merge(default_opts, opts)

    Logger.info("HTTPS opts: #{inspect(result)}")

    if Enum.empty?(result) do
      false
    else
      result
    end
  end

  # Convert environment variable values based on type.
  defp convert_opt(:cacerts, value), do: convert_pem_cert(value)
  defp convert_opt(:cacertfile, value), do: value
  defp convert_opt(:cert, value), do: convert_pem_cert(value)
  defp convert_opt(:certfile, value), do: value
  # defp convert_opt(:cipher_suite, value), do: String.to_existing_atom(value)
  defp convert_opt(:key, value), do: convert_pem_pkey(value)
  defp convert_opt(:keyfile, value), do: value
  defp convert_opt(:port, value) when is_binary(value), do: String.to_integer(value)
  defp convert_opt(:port, value) when is_integer(value), value

  @doc "Convert PEM-encoded certificate to Erlang public_key format."
  @spec convert_pem_cert(binary()) :: [:public_key.pem_entry()]
  def convert_pem_cert(value) do
    value
    |> String.replace("\\n", "\n")
    |> :public_key.pem_decode()
    |> Enum.map(fn {:Certificate, der, :not_encrypted} -> der end)
  end

  @doc "Convert PEM-encoded private key to Erlang public_key format."
  @spec convert_pem_pkey(binary()) :: :public_key.pem_entry()
  def convert_pem_pkey(value) do
    value
    |> String.replace("\\n", "\n")
    |> :public_key.pem_decode()
    |> Enum.map(fn {type, der, :not_encrypted} -> {type, der} end)
    |> Enum.at(0)
  end

  defp empty?(""), do: true
  defp empty?(nil), do: true
  defp empty?(_), do: false
end
