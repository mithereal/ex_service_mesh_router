defmodule ExServiceMeshRouter.Mesh.CompilerTest do
  use ExUnit.Case, async: false

  alias ExServiceMeshRouter.Mesh.Compiler
  alias ExServiceMeshRouter.Discovery.AutoRegistry

  setup do
    :ets.delete_all_objects(:mesh_auto_registry)
    :ok
  end

  test "full compile pipeline produces registry entries" do
    assert :ok = Compiler.compile()

    apps = AutoRegistry.list()

    assert is_list(apps)
    assert length(apps) > 0

    Enum.each(apps, fn app ->
      assert {:ok, _} = AutoRegistry.lookup(app)
    end)
  end

  test "compile_app writes valid manifest to priv" do
    app = %{app: :app_a, path: "apps/app_a"}

    assert {:ok, _} = Compiler.compile_app(app)

    path = "apps/app_a/priv/manifest.json"

    assert File.exists?(path)

    {:ok, json} = File.read(path)
    assert {:ok, decoded} = Jason.decode(json)

    assert Map.has_key?(decoded, "http")
    assert Map.has_key?(decoded, "ws")
  end
end