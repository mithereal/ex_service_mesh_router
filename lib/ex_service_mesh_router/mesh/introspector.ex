defmodule ExServiceMeshRouter.Mesh.Introspector do
  @moduledoc """
  Extracts routing + socket metadata from Phoenix apps.
  """

  def extract(%{app: app, path: path}) do
    %{
      app: app,
      http: extract_http(path),
      ws: extract_ws(path),
      domains: ["localhost"]
    }
  end

  # -----------------------------
  # HTTP ROUTES
  # -----------------------------
  defp extract_http(_path) do
    # In real system: Phoenix.Router.__routes__/0 or AST parse
    %{
      "/api/users" => ["GET", "POST"],
      "/api/health" => ["GET"]
    }
  end

  # -----------------------------
  # WS TOPICS
  # -----------------------------
  defp extract_ws(_path) do
    %{
      topics: [
        "room:*",
        "user:*"
      ]
    }
  end
end