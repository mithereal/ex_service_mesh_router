defmodule ExServiceMeshRouter.Mesh.DiffTest do
  use ExUnit.Case, async: true

  alias ExServiceMeshRouter.Mesh.Diff

  test "detects changes between manifests" do
    old = %{
      http: %{"a" => ["GET"]},
      ws: %{topics: ["room:*"]}
    }

    new = %{
      http: %{"a" => ["GET", "POST"]},
      ws: %{topics: ["room:*"]}
    }

    assert Diff.changed?(old, new) == true
  end

  test "diff returns structured change set" do
    old = %{a: 1}
    new = %{a: 2}

    result = Diff.diff(old, new)

    assert result.changed == true
    assert result.old == old
    assert result.new == new
  end

  test "identical manifests return no change" do
    m = %{a: 1}

    assert Diff.changed?(m, m) == false
  end
end