defmodule ExServiceMeshRouter.ProtocolTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Protocol.{Frame, Builder, Validator}

  test "builds frame from event" do
    event = %ExServiceMeshRouter.Core.MeshEvent{
      type: :http,
      app: :app_a,
      path: "/x",
      method: "GET",
      headers: %{},
      payload: %{}
    }

    frame = Builder.from_event(event)

    assert frame.app == :app_a
    assert frame.type == :http
  end

  test "validates frame" do
    frame = Frame.new(%{type: :http, app: :app_a, payload: %{}})

    assert :ok = Validator.validate(frame)
  end
end