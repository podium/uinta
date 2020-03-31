# Uinta

Uinta is a plugin for the default Elixir logger that lowers log volume while
maximizing log usefulness. It is not a logger backend, but rather includes
`Uinta.Formatter` which will format logs on top of the default Elixir logger
backend.

In addition to the formatter, Uinta also includes `Uinta.Plug`. The plug is a
drop-in replacement for `Plug.Logger` that will log out the request and response
on a single line. It can also put the request info into the top-level JSON for
easier parsing by your log aggregator.

## Why Uinta?

At Podium we log millions of lines per minute and store around a terabyte of log
data per day. A large percentage of those lines are the typical `GET /` and
`Sent 200 in 2ms` that `Plug.Logger` sends by default. By combining those into a
single line, we're able to cut out that percentage of lines so that the indexes
in our Elasticsearch cluster will be smaller and searches will be faster.

In addition, about 2/3 of those requests are GraphQL requests. Their first log
line simply says `POST /graphql` every time, which gives us no insight into what
the request is actually doing. `Uinta.Plug` will extract GraphQL query names
when they exist to make these log lines more useful without having to enable
debug logs: `QUERY messagesForLocation` or `MUTATION createMessage`.

Uinta will additionally wrap the log line in a JSON object so that it can more
easily be parsed by Fluentbit and other log parsers. This increases log line
size, but improves searchability and makes logs more useful.

## Installation

The package can be installed by adding `uinta` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:uinta, "~> 0.4"}
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
