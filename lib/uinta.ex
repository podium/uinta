defmodule Uinta do
  @moduledoc """
  Uinta is a plugin for the default Elixir logger that lowers log volume while
  maximizing log usefulness. It is not a logger backend, but rather includes
  `Uinta.Formatter` which will format logs on top of the default Elixir logger
  backend.

  In addition to the formatter, Uinta also includes `Uinta.Plug`. The plug is a
  drop-in replacement for `Plug.Logger` that will log out the request and
  response on a single line. It can also put the request info into the
  top-level JSON for easier parsing by your log aggregator.

  ## Installation

  The formatter and plug will be installed separately depending on the
  functionality that you want.

  To install the formatter, see the instructions in `Uinta.Formatter`

  To install the plug, see the instructions in `Uinta.Plug`
  """
end
