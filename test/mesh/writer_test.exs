defmodule ExServiceMeshRouter.Mesh.WriterTest do
  use ExUnit.Case, async: true

  alias ExServiceMeshRouter.Mesh.Writer

  test "writes manifest into app priv directory" do
    manifest = %{
      app: "app_test",
      http: %{},
      ws: %{topics: []},
      version: 1
    }

    path = "apps/app_test"

    File.mkdir_p!("apps/app_test/priv")

    assert :ok = Writer.write(path, manifest)

    file = Path.join(path, "priv/manifest.json")

    assert File.exists?(file)

    {:ok, content} = File.read(file)
    assert {:ok, _} = Jason.decode(content)
  end
end