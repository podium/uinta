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

    You will also gain the ability to not log certain paths that are requested,
    as long as those paths return a 200-level status code. This can be
    particularly useful for things like not showing health checks in your logs
    to cut down on noise. To do this, just pass `ignored_paths:
    ["/path_to_ignore"]` in the options.

    Finally, GraphQL requests will replace `POST /graphql` with the GraphQL
    operation type and name like `QUERY getUser` or `MUTATION createUser` if an
    operation name is provided. This will give you more visibility into your
    GraphQL requests without having to log out the entire request body or go
    into debug mode. If desired, the GraphQL variables can be included in the
    log line as well. The query can also be included if unnamed.

    ## Installation

    Installation of the plug will depend on how your app currently logs requests.
    Open `YourApp.Endpoint` and look for the following line:

    ```
    plug Plug.Logger
    ```

    If it exists in your endpoint, replace it with this (using the options you
    want):

    ```
    plug Uinta.Plug,
      log: :info,
      format: :string,
      include_variables: false,
      ignored_paths: [],
      filter_variables: [],
      success_log_sampling_ratio: 1.0,
      include_datadog_fields: false
    ```

    If your endpoint didn't call `Plug.Logger`, add the above line above the line
    that looks like this:

    ```
    plug Plug.RequestId
    ```

    Now you will also want to add the following anywhere in your main config file to
    make sure that you aren't logging each request twice:

    ```
    config :phoenix, logger: false
    ```

    ## Options

    - `:log` - The log level at which this plug should log its request info.
    Default is `:info`
    - `:format` - Output format, either :json, :string, or :map. Default is `:string`
    - `:json` - Whether or not plug should log in JSON format. Default is `false` (obsolete)
    - `:ignored_paths` - A list of paths that should not log requests. Default
    is `[]`.
    - `:include_variables` - Whether or not to include any GraphQL variables in
    the log line when applicable. Default is `false`.
    - `:filter_variables` - A list of variable names that should be filtered
    out from the logs. By default `password`, `passwordConfirmation`,
    `idToken`, and `refreshToken` will be filtered.
    - `:include_unnamed_queries` - Whether or not to include the full query
    body for queries with no name supplied
    - `:success_log_sampling_ratio` - What percentage of successful requests
    should be logged. Defaults to 1.0
    - `:include_datadog_fields` - Whether or not to add logger specific field based on Datadog logger.  Default is
    `false`. See https://docs.datadoghq.com/logs/log_configuration/attributes_naming_convention/#http-requests for details
    """
    @behaviour Plug

    alias Plug.Conn
    require Logger

    @default_filter ~w(password passwordConfirmation idToken refreshToken)
    @default_sampling_ratio 1.0

    @query_name_regex ~r/^\s*(?:query|mutation)\s+(\w+)|{\W+(\w+)\W+?{/m

    @type format :: :json | :map | :string
    @type graphql_info :: %{type: String.t(), operation: String.t(), variables: String.t() | nil}
    @type opts :: %{
            level: Logger.level(),
            format: format(),
            include_unnamed_queries: boolean(),
            include_variables: boolean(),
            include_datadog_fields: boolean(),
            ignored_paths: list(String.t()),
            filter_variables: list(String.t())
          }

    @impl Plug
    def init(opts) do
      format =
        case Keyword.fetch(opts, :format) do
          {:ok, :json = value} ->
            value

          {:ok, :map = value} ->
            value

          {:ok, :string = value} ->
            value

          :error ->
            if Keyword.get(opts, :json, false), do: :json, else: :string
        end

      %{
        level: Keyword.get(opts, :log, :info),
        format: format,
        ignored_paths: Keyword.get(opts, :ignored_paths, []),
        include_unnamed_queries: Keyword.get(opts, :include_unnamed_queries, false),
        include_variables: Keyword.get(opts, :include_variables, false),
        filter_variables: Keyword.get(opts, :filter_variables, @default_filter),
        include_datadog_fields: Keyword.get(opts, :include_datadog_fields, false),
        success_log_sampling_ratio:
          Keyword.get(
            opts,
            :success_log_sampling_ratio,
            @default_sampling_ratio
          )
      }
    end

    @impl Plug
    def call(conn, opts) do
      start = System.monotonic_time()

      Conn.register_before_send(conn, fn conn ->
        log_request(conn, start, opts)
        conn
      end)
    end

    defp log_request(conn, start, opts) do
      if should_log_request?(conn, opts) do
        Logger.log(opts.level, fn ->
          stop = System.monotonic_time()
          diff = System.convert_time_unit(stop - start, :native, :microsecond)

          graphql_info = graphql_info(conn, opts)
          info = info(conn, graphql_info, diff, opts)

          format_line(info, opts.format)
        end)
      end
    end

    @spec info(Plug.Conn.t(), graphql_info(), integer(), opts()) :: map()
    defp info(conn, graphql_info, diff, opts) do
      info = %{
        connection_type: connection_type(conn),
        method: method(conn, graphql_info),
        path: conn.request_path,
        operation_name: graphql_info[:operation],
        query: query(graphql_info, opts),
        status: Integer.to_string(conn.status),
        timing: formatted_diff(diff),
        duration_ms: diff / 1000,
        client_ip: client_ip(conn),
        user_agent: get_first_value_for_header(conn, "user-agent"),
        referer: get_first_value_for_header(conn, "referer"),
        x_forwarded_for: get_first_value_for_header(conn, "x-forwarded-for"),
        x_forwarded_proto: get_first_value_for_header(conn, "x-forwarded-proto"),
        x_forwarded_port: get_first_value_for_header(conn, "x-forwarded-port"),
        via: get_first_value_for_header(conn, "via"),
        variables: variables(graphql_info)
      }

      case opts[:include_datadog_fields] do
        true ->
          dd_fields = %{
            "http.url" => info[:path],
            "http.status_code" => conn.status,
            "http.method" => info[:method],
            "http.referer" => info[:referer],
            "http.request_id" => Logger.metadata()[:request_id],
            "http.useragent" => info[:user_agent],
            "http.version" => Plug.Conn.get_http_protocol(conn),
            "duration" => info[:duration_ms] * 1_000_000,
            "network.client.ip" => info[:client_ip]
          }

          Map.merge(info, dd_fields)

        _ ->
          info
      end
    end

    @spec format_line(map(), format()) :: iodata() | map()
    defp format_line(info, :map) do
      format_info(info)
    end

    defp format_line(info, :json) do
      info = format_info(info)

      case Jason.encode(info) do
        {:ok, encoded} -> encoded
        _ -> inspect(info)
      end
    end

    defp format_line(info, :string) do
      log = [info.method, ?\s, info.operation_name || info.path]
      log = if is_nil(info.operation_name), do: log, else: [log, " (", info.path, ")"]
      log = if is_nil(info.variables), do: log, else: [log, " with ", info.variables]
      log = [log, " - ", info.connection_type, ?\s, info.status, " in ", info.timing]
      if is_nil(info.query), do: log, else: [log, "\nQuery: ", info.query]
    end

    # Format structured data for output
    @spec format_info(map()) :: map()
    defp format_info(info) do
      info
      |> Map.delete(:connection_type)
      |> Map.reject(fn {_, value} -> is_nil(value) end)
    end

    defp get_first_value_for_header(conn, name) do
      conn
      |> Plug.Conn.get_req_header(name)
      |> List.first()
    end

    def client_ip(conn) do
      case :inet.ntoa(conn.remote_ip) do
        {:error, _} ->
          ""

        ip ->
          List.to_string(ip)
      end
    end

    @spec method(Plug.Conn.t(), graphql_info()) :: String.t()
    defp method(_, %{type: type}), do: type
    defp method(conn, _), do: conn.method

    @spec query(graphql_info(), opts()) :: String.t() | nil
    defp query(_, %{include_unnamed_queries: false}), do: nil
    defp query(%{query: query}, _), do: query
    defp query(_, _), do: nil

    @spec variables(graphql_info() | nil) :: String.t() | nil
    defp variables(%{variables: variables}), do: variables
    defp variables(_), do: nil

    @spec graphql_info(Plug.Conn.t(), opts()) :: graphql_info() | nil
    defp graphql_info(%{method: "POST", params: params = %{"query" => query}}, opts)
         when is_binary(query) do
      type =
        query
        |> String.trim()
        |> query_type()

      if is_nil(type) do
        nil
      else
        %{type: type}
        |> put_operation_name(params)
        |> put_query(params["query"], opts)
        |> put_variables(params["variables"], opts)
      end
    end

    defp graphql_info(_, _), do: nil

    @spec put_operation_name(map(), map()) :: map()
    defp put_operation_name(info, params) do
      operation = operation_name(params)
      Map.put(info, :operation, operation)
    end

    @spec put_query(map(), String.t(), opts()) :: map()
    defp put_query(%{operation: "unnamed"} = info, query, %{include_unnamed_queries: true}),
      do: Map.put(info, :query, query)

    defp put_query(info, _query, _opts), do: info

    @spec put_variables(map(), any(), opts()) :: map()
    defp put_variables(info, _variables, %{include_variables: false}), do: info
    defp put_variables(info, variables, _) when not is_map(variables), do: info

    defp put_variables(info, variables, opts) do
      filtered = filter_variables(variables, opts.filter_variables)

      case Jason.encode(filtered) do
        {:ok, encoded} -> Map.put(info, :variables, encoded)
        _ -> info
      end
    end

    @spec filter_variables(map(), list(String.t())) :: map()
    defp filter_variables(variables, to_filter) do
      variables
      |> Enum.map(&filter(&1, to_filter))
      |> Enum.into(%{})
    end

    @spec filter({String.t(), term()}, list(String.t())) :: {String.t(), term()}
    defp filter({key, value}, to_filter) do
      if key in to_filter do
        {key, "[FILTERED]"}
      else
        {key, value}
      end
    end

    @spec formatted_diff(integer()) :: String.t()
    defp formatted_diff(diff) when diff > 1000 do
      "#{diff |> div(1000) |> Integer.to_string()}ms"
    end

    defp formatted_diff(diff), do: "#{Integer.to_string(diff)}µs"

    @spec connection_type(Plug.Conn.t()) :: String.t()
    defp connection_type(%{state: :set_chunked}), do: "Chunked"
    defp connection_type(_), do: "Sent"

    @spec operation_name(map()) :: String.t() | nil
    defp operation_name(%{"operationName" => name}), do: name

    defp operation_name(%{"query" => query}) do
      case Regex.run(@query_name_regex, query, capture: :all_but_first) do
        [query_name] -> query_name
        _ -> "unnamed"
      end
    end

    defp operation_name(_), do: "unnamed"

    @spec query_type(term()) :: String.t() | nil
    defp query_type("query" <> _), do: "QUERY"
    defp query_type("mutation" <> _), do: "MUTATION"
    defp query_type("{" <> _), do: "QUERY"
    defp query_type(_), do: nil

    defp should_log_request?(conn, opts) do
      cond do
        is_integer(conn.status) and conn.status >= 300 ->
          # log all HTTP status >= 300 (usually errors)
          true

        conn.request_path in opts.ignored_paths ->
          false

        true ->
          should_include_in_sample?(opts[:success_log_sampling_ratio])
      end
    end

    defp should_include_in_sample?(ratio) when is_float(ratio) and ratio >= 1.0, do: true

    defp should_include_in_sample?(ratio) do
      random_float() <= ratio
    end

    # Returns a float (4 digit precision) between 0.0 and 1.0
    #
    # Alternative:
    # :crypto.rand_uniform(1, 10_000) / 10_000
    #
    defp random_float do
      :rand.uniform(10_000) / 10_000
    end
  end
end
