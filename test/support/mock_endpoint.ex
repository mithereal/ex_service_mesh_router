defmodule Router.Integration.MockEndpoint do
  @moduledoc """
  Stub Phoenix Endpoint required by ClusterLifecycleWorker reflection tests.
  """
  def config(:url), do: [host: "test-service.mesh.local"]
  def config(:http), do: [port: 4998]
  def config(_), do: []
end
