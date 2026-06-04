defmodule ExServiceMeshRouter.ManifestDiffTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Discovery.ManifestDiff

  test "detects http route changes" do
    old = %{http: %{"/a" => ["GET"]}}
    new = %{http: %{"/a" => ["POST"]}}

    diff = ManifestDiff.diff(old, new)

    assert diff.http.changed != []
  end

  test "detects added routes" do
    old = %{http: %{}}
    new = %{http: %{"/x" => ["GET"]}}

    diff = ManifestDiff.diff(old, new)

    assert "/x" in diff.http.added
  end
end