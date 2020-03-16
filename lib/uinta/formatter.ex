defmodule Uinta.Formatter do
  @moduledoc """
  The Uinta Formatter will wrap normal log statements in a JSON object. The log
  level, timestamp, and metadata will all be attached to it as parts of the
  object.

  The formatter can also format stuctured log messages. When a JSON string is
  received for formatting, it will be decoded and merged with the map to be
  output. In this way any keys that are passed to it will be on the high level
  object, so that they won't need to be extracted from a secondary object later
  on.

  JSON tends to be a great solution for making logs easily machine parseable,
  while still being mostly human readable. However, it is recommended that if
  you have separate configuration for development and production environments
  that you only enable this in the production environment as it can still
  decrease developer productivity to have to mentally parse JSON during
  development.

  ## Installation

  To use the formatter, you'll need to add it to your logger configuration. In
  your (production) config file, see if you have a line that looks something
  like this:

  ```
  config :logger, :console, format: "[$level] $message\\n"
  ```

  If you have it, you'll want to replace it with this:

  ```
  config :logger, :console, format: {Uinta.Formatter, :format}
  ```

  If you don't have it, you'll want to just add that line.
  """

  @type level :: :debug | :info | :warn | :error
  @type time :: {{1970..10000, 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}

  @doc """
  This function takes in four arguments, as defined by
  [Logger](https://hexdocs.pm/logger/Logger.html#module-custom-formatting):

    - `level` is the log level, one of `:debug`, `:info`, `:warn`, and `:error`
    - `message` is the message to be formatted. This should be iodata
  (typically String or iolist)
    - `timestamp` is a timestamp formatted according to
  `Logger.Formatter.time/0`
    - `metadata` is a keyword list containing metadata that will be included
  with the log line

  However, this line should not be called manually. Instead it should be called
  by configuring the Elixir logger in your project to use it as a custom log
  formatter. See [the installation instructions](#module-installation) for more
  information.
  """
  @spec format(level(), iodata(), time(), Keyword.t()) :: iodata()
  def format(level, message, timestamp, metadata) do
    message
    |> to_map()
    |> add_timestamp_and_level(level, timestamp)
    |> add_metadata(metadata)
    |> Jason.encode!()
    |> Kernel.<>("\n")
  rescue
    _ -> "Could not format: #{inspect({level, message, metadata})}"
  end

  @spec to_map(iodata()) :: map()
  defp to_map(message) when is_binary(message) do
    case Jason.decode(message) do
      {:ok, decoded} -> decoded
      _ -> %{"message" => message}
    end
  end

  defp to_map(message) when is_list(message) do
    %{"message" => to_string(message)}
  rescue
    _e in ArgumentError -> to_map(inspect(message))
  end

  defp to_map(message), do: %{"message" => "#{inspect(message)}"}

  @spec add_timestamp_and_level(map(), atom(), time()) :: map()
  defp add_timestamp_and_level(log, level, timestamp) do
    formatted_timestamp = format_timestamp(timestamp)

    log
    |> Map.put("log_level", level)
    |> Map.put("timestamp", formatted_timestamp)
  end

  @spec add_metadata(map(), Keyword.t()) :: map()
  defp add_metadata(log, metadata) do
    metadata = for {k, v} <- metadata, s = serialize(v), into: %{}, do: {k, s}
    Map.put(log, "metadata", metadata)
  end

  @spec format_timestamp(Logger.Formatter.time()) :: String.t()
  defp format_timestamp({date, {hh, mm, ss, ms}}) do
    with erl_time <- :calendar.local_time_to_universal_time({date, {hh, mm, ss}}),
         {:ok, timestamp} <- NaiveDateTime.from_erl(erl_time, {ms * 1000, 3}),
         {:ok, with_timezone} <- DateTime.from_naive(timestamp, "Etc/UTC"),
         result <- DateTime.to_iso8601(with_timezone) do
      result
    end
  end

  @spec serialize(term()) :: String.t() | nil
  defp serialize(value) do
    cond do
      String.Chars.impl_for(value) ->
        to_string(value)

      Inspect.impl_for(value) ->
        inspect(value)

      true ->
        nil
    end
  end
end
