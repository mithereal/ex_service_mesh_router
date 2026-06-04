defmodule ExServiceMeshRouter.TopicRouterTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Routing.TopicRouter
  alias ExServiceMeshRouter.Discovery.ManifestStore

  import ExServiceMeshRouter.TestHelpers

  setup do
    ManifestStore.update(:app_a, sample_manifest())
    :ok
  end

  test "allows valid ws topic" do
    assert {:ok, _ctx} =
             TopicRouter.route(:app_a, "room:lobby", %{})
  end

  test "rejects invalid ws topic" do
    assert {:error, :topic_not_allowed} =
             TopicRouter.route(:app_a, "invalid:topic", %{})
  end
end