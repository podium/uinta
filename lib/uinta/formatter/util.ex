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
      is_list(value) && Enum.all?(value, &String.Chars.impl_for(&1)) ->
        Enum.map(value, &to_string(&1))

      is_list(value) && Enum.all?(value, &Inspect.impl_for(&1)) ->
        Enum.map(value, &inspect(&1))

      String.Chars.impl_for(value) ->
        to_string(value)

      Inspect.impl_for(value) ->
        inspect(value)

      true ->
        nil
    end
  end
end
