defmodule Uinta.MixProject do
  use Mix.Project

  @project_url "https://github.com/podium/uinta"

  def project do
    [
      app: :uinta,
      name: "Uinta",
      description: "Simpler structured logs and lower log volume for Elixir apps",
      version: "0.10.0",
      elixir: "~> 1.8",
      source_url: @project_url,
      homepage_url: @project_url,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:jason, "~> 1.1"},
      {:plug, ">= 0.0.0", optional: true}
    ]
  end

  defp docs do
    [
      main: "Uinta",
      api_reference: false
    ]
  end

  defp package do
    [
      maintainers: ["Dennis Beatty"],
      licenses: ["MIT"],
      links: %{"GitHub" => @project_url}
    ]
  end
end
