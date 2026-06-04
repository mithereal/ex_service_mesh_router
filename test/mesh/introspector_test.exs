defmodule ExServiceMeshRouter.Mesh.IntrospectorTest do
  use ExUnit.Case, async: true

  alias ExServiceMeshRouter.Mesh.Introspector

  test "extracts http and ws metadata from app" do
    input = %{app: :app_a, path: "apps/app_a"}

    result = Introspector.extract(input)

    assert result.app == :app_a
    assert is_map(result.http)
    assert is_map(result.ws)

    assert Map.has_key?(result.ws, :topics)
    assert is_list(result.ws.topics)
  end
end