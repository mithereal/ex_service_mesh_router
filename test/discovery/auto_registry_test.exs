defmodule ExServiceMeshRouter.AutoRegistryTest do
  use ExUnit.Case, async: true

  alias ExServiceMeshRouter.Discovery.AutoRegistry

  test "register and lookup app" do
    AutoRegistry.register(:app_a, %{host: "localhost", port: 4001})

    assert {:ok, endpoint} = AutoRegistry.lookup(:app_a)
    assert endpoint.port == 4001
  end

  test "fallback discovery assigns deterministic port" do
    {:ok, endpoint} = AutoRegistry.lookup(:unknown_app)

    assert endpoint.host == "localhost"
    assert is_integer(endpoint.port)
  end
end