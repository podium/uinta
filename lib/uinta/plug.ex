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

    @impl Plug
    def init(opts), do: opts

    @impl Plug
    def call(conn, opts) do
      level = Keyword.get(opts, :log, :info)
      json = Keyword.get(opts, :json, false)

      start = System.monotonic_time()

      Conn.register_before_send(conn, fn conn ->
        Logger.log(level, fn ->
          {type, operation} = graphql_info(conn)
          is_graphql = !is_nil(type) && !is_nil(operation)
          graphql_info = if is_graphql, do: {type, operation}, else: nil

          stop = System.monotonic_time()
          diff = System.convert_time_unit(stop - start, :native, :microsecond)

          request = format_request(conn, graphql_info, json)
          response = format_response(conn, diff, json)
          format_line(request, response, json)
        end)

        conn
      end)
    end

    @spec format_line(iodata() | map(), iodata() | map(), boolean()) :: iodata()
    defp format_line(request, response, false), do: [request, " - ", response]

    defp format_line(request, response, true) do
      info = Map.merge(request, response)

      case Jason.encode(info) do
        {:ok, encoded} -> encoded
        _ -> inspect(info)
      end
    end

    @spec format_request(Plug.Conn.t(), {String.t(), String.t()} | nil, boolean()) ::
            iodata() | map()
    defp format_request(conn, nil, true), do: %{method: conn.method, path: conn.request_path}
    defp format_request(conn, nil, false), do: [conn.method, ?\s, conn.request_path]
    defp format_request(_, {type, operation}, true), do: %{method: type, path: operation}
    defp format_request(_, {type, operation}, false), do: [type, ?\s, operation]

    @spec format_response(Plug.Conn.t(), list(String.t()), boolean()) :: iodata() | map()
    defp format_response(conn, diff, true) do
      timing = diff |> formatted_diff() |> Enum.join()
      %{status: Integer.to_string(conn.status), timing: timing}
    end

    defp format_response(conn, diff, false) do
      [connection_type(conn), ?\s, Integer.to_string(conn.status), " in ", formatted_diff(diff)]
    end

    @spec graphql_info(Plug.Conn.t()) :: {String.t() | nil, String.t() | nil}
    defp graphql_info(%{params: params}) do
      operation = params["operationName"]

      type =
        params
        |> Map.get("query", "")
        |> String.trim()
        |> query_type()

      {type, operation}
    end

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
