defmodule Router.ClusterCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.LiveViewTest
      
      # Shared test constants
      @gateway_port 4999
      @mock_app_port 4998
    end
  end

  setup _tags do
    # Global per-test execution logic hooks can be added here
    :ok
  end
end
