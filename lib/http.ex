defmodule Braintree.HTTP do
  @moduledoc """
  Base client for all server interaction, used by all endpoint specific
  modules. This request wrapper coordinates the remote server, headers,
  authorization and SSL options.

  This uses `HTTPoison.Base`, so all of the typical HTTP verbs are avialble.

  Using `Braintree.HTTP` requires the presence of three config values:

  * merchant_id - Braintree merchant id
  * private_key - Braintree private key
  * public_key - Braintree public key

  All three must have values set or a `Braintree.ConfigError` will be raised
  at runtime. All those config values support the `{:system, "VAR_NAME"}`
  as a value - in that case the value will be read from the system environment
  with `System.get_env("VAR_NAME")`.
  """

  require Logger

  alias Braintree.XML.{Decoder, Encoder}

  @endpoints [
    production: "https://api.braintreegateway.com/merchants/",
    sandbox: "https://api.sandbox.braintreegateway.com/merchants/"
  ]

  @cacertfile "/certs/api_braintreegateway_com.ca.crt"

  @headers [
    {"Accept", "application/xml"},
    {"User-Agent", "Braintree Elixir/0.1"},
    {"Accept-Encoding", "gzip"},
    {"X-ApiVersion", "4"},
    {"Content-Type", "application/xml"}
  ]

  @timeout 8000 # (mirrors Hackney default)

  @recv_timeout 5000 # (mirrors Hackney default)

  @doc """
  Centralized request handling function. All convenience structs use this
  function to interact with the Braintree servers. This function can be used
  directly to supplement missing functionality.

  ## Example

      defmodule MyApp.Disbursement do
        alias Braintree.HTTP

        def disburse(params \\ %{}) do
          HTTP.request(:get, "disbursements", params)
        end
      end
  """
  @spec request(atom, binary, binary) ::
        {:ok, Map.t} | {:error, Map.t} | {:error, integer} | {:error, binary}
  def request(method, path, body \\ "") do
    response = :hackney.request(method, build_url(path), build_headers(), encode_body(body), build_options())

    case response do
      {:ok, code, _headers, body} when code >= 200 and code <= 399 ->
        {:ok, decode_body(body)}
      {:ok, 401, _headers, _body} ->
        {:error, :unauthorized}
      {:ok, 404, _headers, _body} ->
        {:error, :not_found}
      {:ok, _code, _headers, body} ->
        {:error, decode_body(body)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  for method <- ~w(get delete post put)a do
    def unquote(method)(path, payload \\ %{}) do
      request(unquote(method), path, payload)
    end
  end

  ## Helper Functions

  @doc false
  def build_url(path) do
    environment = Braintree.get_env(:environment, :sandbox)
    merchant_id = Braintree.get_env(:merchant_id)

    Keyword.fetch!(@endpoints, environment) <> merchant_id <> "/" <> path
  end

  @doc false
  def encode_body(body) when body == "" or body == %{}, do: ""
  def encode_body(body), do: Encoder.dump(body)

  @doc false
  def decode_body(body) do
    body
    |> :zlib.gunzip
    |> String.strip
    |> Decoder.load
  rescue
    ErlangError -> Logger.error("unprocessable response")
  end

  @doc false
  def basic_auth(user, pass) do
    "Basic " <> :base64.encode("#{user}:#{pass}")
  end

  defp build_headers do
    public  = Braintree.get_env(:public_key)
    private = Braintree.get_env(:private_key)

    [{"Authorization", basic_auth(public, private)} | @headers]
  end

  defp build_options do
    path = Path.join(:code.priv_dir(:braintree), @cacertfile)

    [:with_body,
     ssl_options: [cacertfile: path],
     timeout: Braintree.get_env(:timeout, @timeout),
     recv_timeout: Braintree.get_env(:recv_timeout, @recv_timeout)]
  end
end
