defmodule Uinta.PlugTest do
  use ExUnit.Case
  use Plug.Test

  import ExUnit.CaptureLog

  require Logger

  defmodule MyPlug do
    use Plug.Builder

    plug(Uinta.Plug)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule JsonPlug do
    use Plug.Builder

    plug(Uinta.Plug, json: true)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule IncludeVariablesPlug do
    use Plug.Builder

    plug(Uinta.Plug, include_variables: true, filter_variables: ~w(password))
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule IncludeUnnamedQueriesPlug do
    use Plug.Builder

    plug(Uinta.Plug, include_unnamed_queries: true)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyChunkedPlug do
    use Plug.Builder

    plug(Uinta.Plug)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_chunked(conn, 200)
    end
  end

  defmodule MyHaltingPlug do
    use Plug.Builder, log_on_halt: :debug

    plug(:halter)
    defp halter(conn, _), do: halt(conn)
  end

  defmodule MyDebugLevelPlug do
    use Plug.Builder

    plug(Uinta.Plug, log: :debug)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  test "logs proper message to console" do
    message =
      capture_log(fn ->
        MyPlug.call(conn(:get, "/"), [])
      end)

    assert message =~ ~r"\[info\]  GET / - Sent 200 in [0-9]+[µm]s"u

    message =
      capture_log(fn ->
        MyPlug.call(conn(:get, "/hello/world"), [])
      end)

    assert message =~ ~r"\[info\]  GET /hello/world - Sent 200 in [0-9]+[µm]s"u
  end

  test "logs proper graphql message to console" do
    variables = %{"user_uid" => "b1641ddf-b7b0-445e-bcbb-96ef359eae81"}
    params = %{"operationName" => "getUser", "query" => "query getUser", "variables" => variables}

    message =
      capture_log(fn ->
        MyPlug.call(conn(:post, "/graphql", params), [])
      end)

    assert message =~ ~r"\[info\]  QUERY getUser - Sent 200 in [0-9]+[µm]s"u
  end

  test "logs proper json to console" do
    message =
      capture_log(fn ->
        JsonPlug.call(conn(:get, "/"), [])
      end)

    assert message =~
             ~r"{\"method\":\"GET\",\"path\":\"/\",\"status\":\"200\",\"timing\":\"[0-9]+[µm]s\"}"u
  end

  test "logs graphql json to console" do
    variables = %{"user_uid" => "b1641ddf-b7b0-445e-bcbb-96ef359eae81"}
    params = %{"operationName" => "getUser", "query" => "query getUser", "variables" => variables}

    message =
      capture_log(fn ->
        JsonPlug.call(conn(:post, "/graphql", params), [])
      end)

    assert message =~
             ~r"{\"method\":\"QUERY\",\"path\":\"getUser\",\"status\":\"200\",\"timing\":\"[0-9]+[µm]s\"}"u
  end

  test "logs paths with double slashes and trailing slash" do
    message =
      capture_log(fn ->
        MyPlug.call(conn(:get, "/hello//world/"), [])
      end)

    assert message =~ ~r"/hello//world/"u
  end

  test "logs chunked if chunked reply" do
    message =
      capture_log(fn ->
        MyChunkedPlug.call(conn(:get, "/hello/world"), [])
      end)

    assert message =~ ~r"Chunked 200 in [0-9]+[µm]s"u
  end

  test "logs proper log level to console" do
    message =
      capture_log(fn ->
        MyDebugLevelPlug.call(conn(:get, "/"), [])
      end)

    assert message =~ ~r"\[debug\] GET / - Sent 200 in [0-9]+[µm]s"u
  end

  test "includes variables when applicable" do
    variables = %{"user_uid" => "b1641ddf-b7b0-445e-bcbb-96ef359eae81"}
    params = %{"operationName" => "getUser", "query" => "query getUser", "variables" => variables}

    message =
      capture_log(fn ->
        IncludeVariablesPlug.call(conn(:post, "/graphql", params), [])
      end)

    assert message =~ "with {\"user_uid\":\"b1641ddf-b7b0-445e-bcbb-96ef359eae81\"}"
  end

  test "doesn't try to include variables on non-graphql requests" do
    message = capture_log(fn -> IncludeVariablesPlug.call(conn(:post, "/", %{}), []) end)
    refute message =~ "with"
  end

  test "doesn't try to include variables when none were given" do
    params = %{"operationName" => "getUser", "query" => "query getUser"}

    message =
      capture_log(fn -> IncludeVariablesPlug.call(conn(:post, "/graphql", params), []) end)

    refute message =~ "with"
  end

  test "filters variables when applicable" do
    variables = %{
      "user_uid" => "b1641ddf-b7b0-445e-bcbb-96ef359eae81",
      "password" => "password123"
    }

    params = %{"operationName" => "getUser", "query" => "query getUser", "variables" => variables}

    message =
      capture_log(fn ->
        IncludeVariablesPlug.call(conn(:post, "/graphql", params), [])
      end)

    assert message =~
             "with {\"password\":\"[FILTERED]\",\"user_uid\":\"b1641ddf-b7b0-445e-bcbb-96ef359eae81\"}"
  end

  test "gets the GraphQL operation name from the query when it isn't in a separate param" do
    query = """
    mutation CreateReviewForEpisode($ep: Episode!, $review: ReviewInput!) {
      createReview(episode: $ep, review: $review) {
        stars
        commentary
      }
    }
    """

    variables = %{
      "ep" => "JEDI",
      "review" => %{"stars" => 5, "commentary" => "This is a great movie!"}
    }

    params = %{"query" => query, "variables" => variables}

    message = capture_log(fn -> MyPlug.call(conn(:post, "/graphql", params), []) end)
    assert message =~ "MUTATION CreateReviewForEpisode"
  end

  test "gets the GraphQL operation name from the query when there is an array parameter" do
    query = """
    mutation track($userId: String!, $event: String!, $properties: [String]) { 
      track(userId: $userId, event: $event, properties: $properties) { 
        status 
      } 
    }
    """

    variables = %{
      "userId" => "55203f63-0b79-426c-840e-ea68bdac765c",
      "event" => "WEBSITE_WIDGET_PROMPT_SHOW",
      "properties" => ["green", "firefox"]
    }

    params = %{"query" => query, "variables" => variables}

    message = capture_log(fn -> MyPlug.call(conn(:post, "/graphql", params), []) end)
    assert message =~ "MUTATION track"
  end

  test "gets the GraphQL operation name from the query when it uses no commas and has whitespace in the parameters" do
    query = """
    mutation CreateReviewForEpisode( $ep: Episode! $review: ReviewInput! ) {
      createReview(episode: $ep, review: $review) {
        stars
        commentary
      }
    }
    """

    variables = %{
      "ep" => "JEDI",
      "review" => %{"stars" => 5, "commentary" => "This is a great movie!"}
    }

    params = %{"query" => query, "variables" => variables}

    message = capture_log(fn -> MyPlug.call(conn(:post, "/graphql", params), []) end)
    assert message =~ "MUTATION CreateReviewForEpisode"
  end

  test "includes the query when it isn't named" do
    query = """
    {
      hero {
        name
      }
    }
    """

    params = %{"query" => query}

    message =
      capture_log(fn -> IncludeUnnamedQueriesPlug.call(conn(:post, "/graphql", params), []) end)

    assert message =~ "QUERY unnamed"
    assert message =~ "hero {"
  end
end
