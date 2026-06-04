defmodule ExServiceMeshRouter.ValidationTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Routing.Validation
  alias ExServiceMeshRouter.Routing.Context

  import ExServiceMeshRouter.TestHelpers

  test "validates http request success" do
    ctx =
      %Context{
        manifest: sample_manifest(),
        path: "/api/users",
        method: "GET",
        event: %{host: "localhost"},
        type: :http
      }

    assert :ok = Validation.validate(ctx)
  end

  test "rejects invalid method" do
    ctx =
      %Context{
        manifest: sample_manifest(),
        path: "/api/users",
        method: "DELETE",
        event: %{host: "localhost"},
        type: :http
      }

    assert {:error, :method_not_allowed} = Validation.validate(ctx)
  end
end