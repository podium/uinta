defmodule Uinta.FormatterTest do
  use ExUnit.Case
  alias Uinta.Formatter

  test "formats message properly" do
    message = "this is a log message"
    date = {2020, 3, 16}
    time = {10, 16, 32}
    timestamp = {date, Tuple.append(time, 548)}
    metadata = [request_id: "req_1234", user_uid: "26dbba1d-5b72-4e5c-b1a7-701589343291"]

    formatted = Formatter.format(:info, message, timestamp, metadata)

    assert formatted ==
             "{\"log_level\":\"info\",\"message\":\"this is a log message\",\"metadata\":{\"request_id\":\"req_1234\",\"user_uid\":\"26dbba1d-5b72-4e5c-b1a7-701589343291\"},\"timestamp\":\"2020-03-16T10:16:32.548Z\"}\n"
  end

  test "merges with log message json when applicable" do
    message = "{\"method\":\"GET\",\"path\":\"/\",\"status\":\"200\",\"timing\":\"69µs\"}"
    date = {2020, 3, 16}
    timestamp = {date, {10, 16, 32, 548}}
    metadata = [request_id: "req_1234", user_uid: "26dbba1d-5b72-4e5c-b1a7-701589343291"]

    formatted = Formatter.format(:info, message, timestamp, metadata)

    assert formatted ==
             "{\"log_level\":\"info\",\"metadata\":{\"request_id\":\"req_1234\",\"user_uid\":\"26dbba1d-5b72-4e5c-b1a7-701589343291\"},\"method\":\"GET\",\"path\":\"/\",\"status\":\"200\",\"timestamp\":\"2020-03-16T10:16:32.548Z\",\"timing\":\"69µs\"}\n"
  end

  test "formats metadata values that are lists of atoms" do
    metadata = [prop: [:elixir]]
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, metadata)

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "[:elixir]"
  end

  test "formats metadata datetime values" do
    metadata = [prop: ~U[2022-07-26 22:07:46.217735Z]]
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, metadata)

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "2022-07-26 22:07:46.217735Z"
  end

  test "formats metadata string values" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: "test")

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "test"
  end

  test "formats metadata integer values" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: 1)

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "1"
  end

  test "formats metadata float values" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: 0.1)

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "0.1"
  end

  test "formats metadata boolean values" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: true)

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "true"
  end

  test "formats metadata atom values" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: :test)

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "test"
  end

  test "formats metadata tuple values" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: {:test})

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "{:test}"
  end

  test "formats metadata map values" do
    result =
      Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: %{test: "test"})

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "%{test: \"test\"}"
  end

  test "formats metadata charlist" do
    result = Formatter.format(:info, "Testing", {{1980, 1, 1}, {0, 0, 0, 0}}, prop: ~c"abc")

    %{"metadata" => %{"prop" => metadata_value}} = Jason.decode!(result)
    assert metadata_value == "abc"
  end
end
