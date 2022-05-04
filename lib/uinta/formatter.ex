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

  ## Available Formatters

  ### Standard

  No special handling, outputs everything as JSON.

  ### Datadog

  Support adding Datadog specific metadata to logs.
  """
  alias Uinta.Types

  @doc """
  This function takes in four arguments, as defined by
  [Logger](https://hexdocs.pm/logger/Logger.html#module-custom-formatting):

    - `level` is the log level, one of `:debug`, `:info`, `:warn`, and `:error`
    - `message` is the message to be formatted. This should be iodata
  (typically String or iolist)
    - `timestamp` is a timestamp formatted according to
  `t:Logger.Formatter.time/0`
    - `metadata` is a keyword list containing metadata that will be included
  with the log line

  However, this line should not be called manually. Instead it should be called
  by configuring the Elixir logger in your project to use it as a custom log
  formatter. See [the installation instructions](#module-installation) for more
  information.

  Delegates to Uinta.Formatter.Standard for backward compatibility
  """
  @spec format(Types.level(), iodata(), Types.time(), Keyword.t()) :: iodata()
  defdelegate format(level, message, timestamp, metadata), to: Uinta.Formatter.Standard
end
