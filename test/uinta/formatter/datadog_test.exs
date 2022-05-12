defmodule Uinta.Formatter.DatadogTest do
  use ExUnit.Case, async: true

  alias Uinta.Formatter.Datadog

  describe "format/4" do
    test "it adds dd.trace_id and dd.span_id when properties are hex" do
      metadata = [trace_id: "e4705f4a1b95d6ae5ec373e00f013b91", span_id: "8e00cc3f6e137140"]
      result = Datadog.format(:info, "Hello World", {{1980, 1, 1}, {0, 0, 0, 0}}, metadata)

      %{"dd.trace_id" => trace_id, "dd.span_id" => span_id} = Jason.decode!(result)
      assert trace_id == "6828428866185411473"
      assert span_id == "10232402926187540800"
    end
  end
end
