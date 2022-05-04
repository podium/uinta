defmodule Uinta.Formatter.Datadog do
  @moduledoc """

  ## Installation

  ```
  config :logger, :console, format: {Uinta.Formatter.Datadog, :format}
  ```

  ## Features

  ### Trace and Span id correlation

  Takes trace ids and span ids in the OpenTelemetry format (as hex) and convert them into Datadog
  format in the correct key. Logger.metadata must include the keys `:trace_id` and `:span_id`.
  Be sure to add those two keys onto the allowlist in the `:logger` config. See
  [Datadog's documentation](https://docs.datadoghq.com/tracing/connect_logs_and_traces/opentelemetry/)
  for more details.

  #### Example

  ```elixir
  ctx = OpenTelemetry.Tracer.current_span_ctx()
  Logger.metadata([
    trace_id: OpenTelemetry.Span.hex_trace_id(ctx),
    span_id: OpenTelemetry.Span.hex_span_id(ctx)
  ])
  ```
  """

  alias Uinta.Formatter.Util
  alias Uinta.Types

  @doc """
  See Uinta.formatter.format/4
  """
  @spec format(Types.level(), iodata(), Types.time(), Keyword.t()) :: iodata()
  def format(level, message, timestamp, metadata) do
    Util.format(level, message, timestamp, metadata)
    |> add_datadog_trace(metadata)
    |> Util.encode()
  rescue
    e ->
      IO.inspect(e)
      "Could not format: #{inspect({level, message, metadata})}"
  end

  @spec add_datadog_trace(map(), Keyword.t()) :: map()
  defp add_datadog_trace(log, metadata) do
    log
    |> Map.put("dd.trace_id", to_datadog_id(Keyword.get(metadata, :trace_id)))
    |> Map.put("dd.span_id", to_datadog_id(Keyword.get(metadata, :span_id)))
  end

  defp to_datadog_id(id) when is_nil(id), do: nil

  defp to_datadog_id(<<high::bytes-size(16)>><><<low::bytes-size(16)>>) do
    #  OpenTelemetry uses 128 bits for the trace id and 64 bits for the span id.
    #  DataDog uses the lower 64 bits of each, as an unsigned integer, for its trace/span ids.
    to_datadog_id(low)
  end

  defp to_datadog_id(id) do
    case Integer.parse(id, 16) do
      {integer, _remainder_of_binary} ->
        Integer.to_string(integer, 10)

      _error ->
        nil
    end
  end
end
