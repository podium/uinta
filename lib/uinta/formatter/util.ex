defmodule Uinta.Formatter.Util do
  @moduledoc """
  Utilities for building a formatter
  """

  alias Uinta.Types

  @doc """
  Format as a map with metadata as a map, timestamp, level, and message.
  """
  def format(level, message, timestamp, metadata) do
    message
    |> to_map()
    |> add_timestamp_and_level(level, timestamp)
    |> add_metadata(metadata)
  end

  @doc """
  Stringify as JSON
  """
  @spec encode(map()) :: String.t()
  def encode(formatted_logs) do
    formatted_logs
    |> Jason.encode!()
    |> Kernel.<>("\n")
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

  @spec add_timestamp_and_level(map(), atom(), Types.time()) :: map()
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

  @doc """
  RFC3339 UTC "Zulu" format.
  """
  @spec format_timestamp(Types.time()) :: String.t()
  def format_timestamp({date, time}) do
    IO.iodata_to_binary([format_date(date), ?T, format_time(time), ?Z])
  end

  defp format_date({yy, mm, dd}) do
    [Integer.to_string(yy), ?-, pad2(mm), ?-, pad2(dd)]
  end

  defp format_time({hh, mi, ss, ms}) do
    [pad2(hh), ?:, pad2(mi), ?:, pad2(ss), ?., pad3(ms)]
  end

  defp pad3(int) when int < 10, do: [?0, ?0, Integer.to_string(int)]
  defp pad3(int) when int < 100, do: [?0, Integer.to_string(int)]
  defp pad3(int), do: Integer.to_string(int)

  defp pad2(int) when int < 10, do: [?0, Integer.to_string(int)]
  defp pad2(int), do: Integer.to_string(int)

  @spec serialize(term()) :: String.t() | nil
  defp serialize(value) do
    cond do
      String.Chars.impl_for(value) ->
        serialize_to_string(value)

      Inspect.impl_for(value) ->
        inspect(value)

      true ->
        nil
    end
  end

  defp serialize_to_string(value) do
    to_string(value)
  rescue
    _ -> inspect(value)
  end
end
