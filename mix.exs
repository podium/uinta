defmodule Uinta.MixProject do
  use Mix.Project

  def project do
    [
      app: :uinta,
      name: "Uinta",
      version: "0.1.0",
      elixir: "~> 1.9",
      source_url: "https://github.com/podium/uinta",
      homepage_url: "https://github.com/podium/uinta",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :docs, runtime: false},
      {:jason, "~> 1.1"},
      {:plug, "~> 1.9", optional: true}
    ]
  end

  defp docs do
    [
      main: "Uinta",
      api_reference: false
    ]
  end
end
