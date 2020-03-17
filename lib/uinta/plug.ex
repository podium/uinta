if Code.ensure_loaded?(Plug) do
  defmodule Uinta.Plug do
    @moduledoc """
    This plug combines the request and response logs into a single line. This
    brings many benefits including:

    - Removing the need to visually match up the request and response makes it
    easier to read your logs and get a full picture of what has happened.

    - Having a single line for both request and response halves the number of
    request logs that your log aggregator will need to process and index, which
    leads to saved costs

    In addition to combining the log lines, it also gives you the ability to
    output request logs in JSON format so that you can easily have your log
    aggregator parse the fields. To do this, pass `json: true` in the options
    when calling the plug.

    ## Installation

    To install this, find this line (typically in `YourApp.Endpoint`):

    ```
    plug Plug.Logger
    ```

    and replace it with this (using only the options you want):

    ```
    plug Uinta.Plug, json: false, log: :info
    ```

    ## Options

    - `:json` - Whether or not this plug should log in JSON format. Default is
    `false`
    - `:log` - The log level at which this plug should log its request info.
    Default is `:info`
    """

    require Logger
    alias Plug.Conn
    @behaviour Plug

    @type format :: :json | :string
    @type graphql_info :: %{type: String.t(), operation: String.t(), variables: String.t() | nil}

    @impl Plug
    def init(opts), do: opts

    @impl Plug
    def call(conn, opts) do
      level = Keyword.get(opts, :log, :info)
      json = if Keyword.get(opts, :json, false), do: :json, else: :string
      include_variables = Keyword.get(opts, :include_variables, false)

      start = System.monotonic_time()

      Conn.register_before_send(conn, fn conn ->
        Logger.log(level, fn ->
          graphql_info = graphql_info(conn, include_variables)

          stop = System.monotonic_time()
          diff = System.convert_time_unit(stop - start, :native, :microsecond)

          request = format_request(conn, graphql_info, json)
          response = format_response(conn, diff, json)
          format_line(request, response, json)
        end)

        conn
      end)
    end

    @spec format_line(iodata() | map(), iodata() | map(), format()) :: iodata()
    defp format_line(request, response, :string), do: [request, " - ", response]

    defp format_line(request, response, :json) do
      info = Map.merge(request, response)

      case Jason.encode(info) do
        {:ok, encoded} -> encoded
        _ -> inspect(info)
      end
    end

    @spec method(Plug.Conn.t(), graphql_info()) :: String.t()
    defp method(_, %{type: type}), do: type
    defp method(conn, _), do: conn.method

    @spec path(Plug.Conn.t(), graphql_info()) :: String.t()
    defp path(_, %{operation: operation}), do: operation
    defp path(conn, _), do: conn.request_path

    @spec variables(graphql_info() | nil) :: String.t() | nil
    defp variables(%{variables: variables}), do: variables
    defp variables(_), do: nil

    @spec format_request(Plug.Conn.t(), graphql_info(), format()) :: iodata() | map()
    defp format_request(conn, graphql_info, :json) do
      log = %{method: method(conn, graphql_info), path: path(conn, graphql_info)}
      variables = variables(graphql_info)
      if is_nil(variables), do: log, else: Map.put(log, :variables, variables)
    end

    defp format_request(conn, graphql_info, :string) do
      log = [method(conn, graphql_info), ?\s, path(conn, graphql_info)]
      variables = variables(graphql_info)
      if is_nil(variables), do: log, else: [log, " with ", variables]
    end

    @spec format_response(Plug.Conn.t(), list(String.t()), format()) :: iodata() | map()
    defp format_response(conn, diff, :json) do
      timing = diff |> formatted_diff() |> Enum.join()
      %{status: Integer.to_string(conn.status), timing: timing}
    end

    defp format_response(conn, diff, :string) do
      [connection_type(conn), ?\s, Integer.to_string(conn.status), " in ", formatted_diff(diff)]
    end

    @spec graphql_info(Plug.Conn.t(), boolean()) :: graphql_info() | nil
    defp graphql_info(%{method: "POST", params: params}, include_variables) do
      operation = params["operationName"]
      variables = params["variables"]

      encoded_variables =
        with true <- include_variables,
             {:ok, encoded} <- Jason.encode(variables) do
          encoded
        else
          _ -> nil
        end

      type =
        params
        |> Map.get("query", "")
        |> String.trim()
        |> query_type()

      if !is_nil(type) && !is_nil(operation) do
        %{type: type, operation: operation, variables: encoded_variables}
      else
        nil
      end
    end

    defp graphql_info(_, _), do: nil

    @spec formatted_diff(integer()) :: list(String.t())
    defp formatted_diff(diff) when diff > 1000,
      do: [diff |> div(1000) |> Integer.to_string(), "ms"]

    defp formatted_diff(diff), do: [Integer.to_string(diff), "µs"]

    @spec connection_type(Plug.Conn.t()) :: String.t()
    defp connection_type(%{state: :set_chunked}), do: "Chunked"
    defp connection_type(_), do: "Sent"

    @spec query_type(term()) :: String.t() | nil
    defp query_type("query" <> _), do: "QUERY"
    defp query_type("mutation" <> _), do: "MUTATION"
    defp query_type(_), do: nil
  end
end
