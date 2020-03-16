defmodule Uinta.FormatterTest do
  use ExUnit.Case
  alias Uinta.Formatter

  test "formats message properly" do
    message = "this is a log message"
    timestamp = {{2020, 3, 16}, {10, 16, 32, 548}}
    metadata = [request_id: "req_1234", user_uid: "26dbba1d-5b72-4e5c-b1a7-701589343291"]

    formatted = Formatter.format(:info, message, timestamp, metadata)

    assert formatted ==
             "{\"log_level\":\"info\",\"message\":\"this is a log message\",\"metadata\":{\"request_id\":\"req_1234\",\"user_uid\":\"26dbba1d-5b72-4e5c-b1a7-701589343291\"},\"timestamp\":\"2020-03-16T16:16:32.548Z\"}\n"
  end

  test "merges with log message json when applicable" do
    message = "{\"method\":\"GET\",\"path\":\"/\",\"status\":\"200\",\"timing\":\"69µs\"}"
    timestamp = {{2020, 3, 16}, {10, 16, 32, 548}}
    metadata = [request_id: "req_1234", user_uid: "26dbba1d-5b72-4e5c-b1a7-701589343291"]

    formatted = Formatter.format(:info, message, timestamp, metadata)

    assert formatted ==
             "{\"log_level\":\"info\",\"metadata\":{\"request_id\":\"req_1234\",\"user_uid\":\"26dbba1d-5b72-4e5c-b1a7-701589343291\"},\"method\":\"GET\",\"path\":\"/\",\"status\":\"200\",\"timestamp\":\"2020-03-16T16:16:32.548Z\",\"timing\":\"69µs\"}\n"
  end
end
