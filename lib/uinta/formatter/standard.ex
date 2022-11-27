defmodule Uinta.Formatter.Standard do
  @moduledoc """
  No special handling, outputs everything as JSON. See Uinta.Formatter for more information.
  """

  alias Uinta.Formatter.Util
  alias Uinta.Types

  @type level :: :debug | :info | :warn | :error
  @type time :: {{1970..10_000, 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}

  @doc """
  See Uinta.formatter.format/4
  """
  @spec format(Types.level(), iodata(), Types.time(), Keyword.t()) :: iodata()
  def format(level, message, timestamp, metadata) do
    level |> Util.format(message, timestamp, metadata) |> Util.encode()
  rescue
    e ->
      "Could not format: #{inspect({level, message, metadata})}, Due to error: #{inspect(e)}"
  end
end
