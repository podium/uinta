defmodule Uinta.MixProject do
  use Mix.Project

  @project_url "https://github.com/podium/uinta"
  @version "0.15.1"

  def project do
    [
      app: :uinta,
      name: "Uinta",
      description: "Simpler structured logs and lower log volume for Elixir apps",
      version: @version,
      elixir: "~> 1.14",
      source_url: @project_url,
      homepage_url: @project_url,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer.ignore-warnings",
        list_unused_filters: true,
        plt_add_apps: [:mix]
      ],
      docs: docs(),
      package: package(),
      test_coverage: [summary: [threshold: 80]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.10", optional: true}
    ]
  end

  defp docs do
    [
      main: "Uinta",
      extras: [
        "CHANGELOG.md",
        {:"README.md", title: "Readme"}
      ],
      source_url: @project_url,
      source_ref: "v#{@version}",
      homepage_url: @project_url
    ]
  end

  defp package do
    [
      maintainers: ["Podium"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @project_url,
        "Changelog" => "#{@project_url}/blob/master/CHANGELOG.md"
      }
    ]
  end
end
