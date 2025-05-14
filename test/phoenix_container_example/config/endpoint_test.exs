defmodule PhoenixContainerExample.Config.EndpointTest do
  use ExUnit.Case, async: true

  alias PhoenixContainerExample.Config.Endpoint, as: EndpointConfig

  test "no config returns false" do
    assert EndpointConfig.https_opts(%{}, %{}, []) == false

    result =
      EndpointConfig.https_opts(
        %{},
        %{
          "HTTPS_CACERTS" => :cacerts,
          "HTTPS_CACERTFILE" => :cacertfile,
          "HTTPS_CERT" => :cert,
          "HTTPS_CERTFILE" => :certfile,
          # "HTTPS_CIPHER_SUITE" => :cipher_suite,
          "HTTPS_KEY" => :key,
          "HTTPS_KEYFILE" => :keyfile,
          "HTTPS_PORT" => :port
        },
        port: String.to_integer(System.get_env("HTTPS_PORT") || "4443"),
        cipher_suite: :stron,
        log_level: :warning
      )

    assert result == false
  end

  describe "bandit" do
    test "files" do
      env = %{
        "HTTPS_CACERTFILE" => "/etc/foo/ssl/cacert.pem",
        "HTTPS_CERTFILE" => "/etc/foo/ssl/cert.pem",
        "HTTPS_KEYFILE" => "/etc/foo/ssl/key.pem"
        # "HTTPS_PORT" => "4443"
      }

      config = %{
        "HTTPS_CACERTS" => :cacerts,
        "HTTPS_CACERTFILE" => :cacertfile,
        "HTTPS_CERT" => :cert,
        "HTTPS_CERTFILE" => :certfile,
        "HTTPS_KEY" => :key,
        "HTTPS_KEYFILE" => :keyfile,
        "HTTPS_PORT" => :port
      }

      result = EndpointConfig.https_opts(env, config, port: 4443)

      expected = [
        keyfile: "/etc/foo/ssl/key.pem",
        certfile: "/etc/foo/ssl/cert.pem",
        thousand_island_options: [
          transport_options: [
            cacertfile: "/etc/foo/ssl/cacert.pem"
          ]
        ],
        scheme: :https,
        port: 4443
      ]

      assert result == expected
    end
  end

  describe "cowboy" do
    test "files" do
      env = %{
        "HTTPS_CACERTFILE" => "/etc/foo/ssl/cacert.pem",
        "HTTPS_CERTFILE" => "/etc/foo/ssl/cert.pem",
        "HTTPS_KEYFILE" => "/etc/foo/ssl/key.pem",
        "HTTPS_PORT" => "4443"
      }

      config = %{
        "HTTPS_CACERTS" => :cacerts,
        "HTTPS_CACERTFILE" => :cacertfile,
        "HTTPS_CERT" => :cert,
        "HTTPS_CERTFILE" => :certfile,
        "HTTPS_KEY" => :key,
        "HTTPS_KEYFILE" => :keyfile,
        "HTTPS_PORT" => :port
      }

      default_opts = [
        adapter: Phoenix.Endpoint.Cowboy2Adapter,
        port: 4443,
        cipher_suite: :strong,
        log_level: :warning
      ]

      result = EndpointConfig.https_opts(env, config, default_opts)

      expected = [
        cipher_suite: :strong,
        log_level: :warning,
        cacertfile: "/etc/foo/ssl/cacert.pem",
        certfile: "/etc/foo/ssl/cert.pem",
        keyfile: "/etc/foo/ssl/key.pem",
        port: 4443
      ]

      assert result == expected
    end
  end
end
