defmodule ExServiceMeshRouter.TimeTest do
  use ExUnit.Case

  alias ExServiceMeshRouter.Utils.Time

  test "returns increasing timestamps" do
    a = Time.now_ms()
    b = Time.now_ms()

    assert b >= a
  end

  test "backoff increases exponentially" do
    assert Time.backoff(1) > Time.backoff(0)
  end
end