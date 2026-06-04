defmodule Router.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/mithereal/ex_service_mesh_router"

  defp package do
    # These are the default files included in the package
    [
      name: :ex_service_mesh_router,
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Jason Clark"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/mithereal/ex_service_mesh_router"}
    ]
  end

  def project do
    [
      app: :ex_service_mesh_router,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ex_service_mesh_router",
      package: package(),
      description: description(),
      docs: docs(),
      aliases: aliases(),
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  def application do
    [
      mod: {Router.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp description do
    "A BEAM-native service mesh gateway for Phoenix umbrella applications with automatic service discovery. Tenant handling is owned by each Phoenix application."
  end

  defp docs do
    [
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.8"},
      {:mint, "~> 1.6"},
      {:jason, "~> 1.4"},
               {:httpoison, "~> 2.0"},
      {:excoveralls, "~> 0.14", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      c: "compile"
    ]
  end
end
