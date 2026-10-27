defmodule ExServiceMeshRouter.MixProject do
  use Mix.Project

  @version "1.0.1"
  @source_url "https://github.com/mithereal/ex_service_mesh_router"

  def project do
    [
      app: :ex_service_mesh_router,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "ExServiceMeshRouter",
      package: package(),
      description: description(),
      docs: docs(),
      aliases: aliases(),
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {ExServiceMeshRouter.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp package do
    [
      name: "ex_service_mesh_router",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Jason Clark"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp description do
    "A BEAM-native service mesh gateway for Phoenix umbrella applications with automatic service discovery. Tenant handling is owned by each Phoenix application."
  end

  defp docs do
    [
      main: "README",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:reverse_proxy_plug, "~> 3.0"},
      {:reverse_proxy_plug_websocket, "0.2.0"},
      {:gun, "~> 2.1"},
      {:req, "~> 0.5"},
      {:plug_cowboy, "~> 2.7", optional: true},
      {:bandit, "~> 1.5", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:websockex, "~> 0.4.3", optional: true},
      {:excoveralls, "~> 0.14", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: [
        "env.test_setup",
        "compile --force",
        fn args -> Mix.Task.run("test", args) end
      ],
      c: "compile"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
