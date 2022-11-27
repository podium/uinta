defmodule Uinta.Types do
  @moduledoc """
  Defines types
  """
  @type level :: :debug | :info | :warn | :error
  @type time :: {{1970..10_000, 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}
end
