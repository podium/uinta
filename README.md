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
`Sent 200 in 2ms` that `Phoenix.Logger` sends by default. By combining those
into a single line, we're able to cut out that percentage of lines so that the
indexes in our Elasticsearch cluster will be smaller and searches will be
faster.

In addition, about 2/3 of those requests are GraphQL requests. Their first log
line simply says `POST /graphql` every time, which gives us no insight into what
the request is actually doing. `Uinta.Plug` will extract GraphQL query names
when they exist to make these log lines more useful without having to enable
debug logs: `QUERY messagesForLocation (/graphql)` or `MUTATION createMessage (/graphql)`.

For smaller organizations, the ability to filter out lines pertaining to certain
requests paths can also be useful to cut down on log noise. Kubernetes health
checks and other requests don't usually need to show up in the logs, so
`Uinta.Plug` allows you to ignore certain paths as long as they return a
200-level status code.

When set up to do so, Uinta will additionally wrap the log line in a JSON object
so that it can more easily be parsed by Fluentbit and other log parsers. This
increases log line size, but improves searchability and makes logs more useful.

## Installation

The package can be installed by adding `uinta` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:uinta, "~> 0.6"}
  ]
end
```

### Available Formatters

#### Standard

No special formatting or fields, good for general use.

Module: `Uinta.Formatter` (or `Uinta.Formatter.Standard`)

#### Datadog

Adds Datadog specific metadata to the log output. See the module for more setup information and details.

Module: `Uinta.Formatter.Datadog`

To enable the full log format to use DataDog log service, just use `include_datadog_fields: true` in your plug initialization

### Formatter Installation

To use the formatter, you'll need to add it to your logger configuration. In
your (production) config file, look for a line that looks something like
this:

```elixir
config :logger, :console, format: "[$level] $message\\n"
```

You'll want to replace it with this:

```elixir
config :logger, :console, format: {Uinta.Formatter, :format}
```

### Plug Installation

Installation of the plug will depend on how your app currently logs requests.
Open `YourApp.Endpoint` and look for the following line:

```elixir
plug Plug.Logger
```

If it exists in your endpoint, replace it with this (using the options you
want):

```elixir
plug Uinta.Plug, json: false, log: :info
```

You can also perform log sampling by setting the `success_log_sampling_ratio`. Following is a 20% log sampling

```elixir
plug Uinta.Plug, success_log_sampling_ratio: 0.2
```

If your endpoint didn't call `Plug.Logger`, add the above line above the line
that looks like this:

```elixir
plug Plug.RequestId
```

Now you will also want to add the following anywhere in your main config file to
make sure that you aren't logging each request twice:

```elixir
config :phoenix, logger: false
```

## Attribution

Much of this work, especially `Uinta.Plug`, is based on Elixir's
[`Plug.Logger`](https://github.com/elixir-plug/plug/blob/v1.9.0/lib/plug/logger.ex)
