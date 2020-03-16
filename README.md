# Uinta

Uinta is a plugin for the default Elixir logger that lowers log volume while
maximizing log usefulness. It is not a logger backend, but rather includes
`Uinta.Formatter` which will format logs on top of the default Elixir logger
backend.

In addition to the formatter, Uinta also includes `Uinta.Plug`. The plug is a
drop-in replacement for `Plug.Logger` that will log out the request and response
on a single line. It can also put the request info into the top-level JSON for
easier parsing by your log aggregator.

## Installation

The package can be installed by adding `uinta` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:uinta, "~> 0.1"}
  ]
end
```

To use the formatter, you'll need to add it to your logger configuration. In
your (production) config file, look for a line that looks something like
this:

```
config :logger, :console, format: "[$level] $message\\n"
```

You'll want to replace it with this:

```
config :logger, :console, format: {Uinta.Formatter, :format}
```

To install the plug, find this line (typically in `YourApp.Endpoint`):

```
plug Plug.Logger
```

and replace it with this (using only the options you want):

```
plug Uinta.Plug, json: false, log: :info
```

## Attribution

Much of this work, especially `Uinta.Plug`, is based on Elixir's
[`Plug.Logger`](https://github.com/elixir-plug/plug/blob/v1.9.0/lib/plug/logger.ex)
