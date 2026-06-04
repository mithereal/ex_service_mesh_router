defmodule ExServiceMeshRouter.Mesh.ScannerTest do
  use ExUnit.Case, async: true

  alias ExServiceMeshRouter.Mesh.Scanner

  test "scans apps directory and returns normalized apps" do
    apps = Scanner.scan()

    assert is_list(apps)
    assert length(apps) > 0

    Enum.each(apps, fn app ->
      assert Map.has_key?(app, :app)
      assert Map.has_key?(app, :path)
      assert is_atom(app.app)
      assert is_binary(app.path)
    end)
  end
end