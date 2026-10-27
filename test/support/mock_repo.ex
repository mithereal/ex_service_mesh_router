defmodule Router.Integration.MockRepo do
  @moduledoc """
  Mock Ecto Repository adapter designed to capture process telemetry mutations
  during multi-tenant testing cycles.
  """

  # Implements the expected process-dictionary interface of an Ecto.Repo
  def put_tenant(tenant) do
    # Save the mutated state directly onto the active test process dictionary thread
    Process.put(:mock_ecto_tenant, tenant)
    :ok
  end

  def get_tenant do
    Process.get(:mock_ecto_tenant)
  end
end
