defmodule ExServiceMeshRouter.Routing.Context do
  @moduledoc """
  Routing context for a single request lifecycle.

  This object is the shared state passed across:
  - AppRouter (ingress validation)
  - EventBus (dispatch)
  - Pipeline Engine (execution)
  - Forwarders (HTTP / WS)

  It normalizes all routing-relevant metadata into one structure.
  """

  defstruct [
    :app,
    :endpoint,
    :manifest,
    :event,
    :path,
    :method,
    :type,
    :target,
    :halted,
    assigns: %{},
    errors: []
  ]

  # -------------------------
  # BUILDERS
  # -------------------------

  @doc """
  Build a routing context from a MeshEvent and resolved app metadata.
  """
  def new(event, app, endpoint, manifest) do
    %__MODULE__{
      event: event,
      app: app,
      endpoint: endpoint,
      manifest: normalize_manifest(manifest),
      path: event.path,
      method: event.method,
      type: event.type,
      halted: false,
      assigns: %{},
      errors: []
    }
  end

  # -------------------------
  # TRANSFORMS
  # -------------------------

  @doc """
  Attach resolved routing target (final upstream destination).
  """
  def put_target(ctx, target) do
    %{ctx | target: target}
  end

  @doc """
  Add arbitrary metadata during pipeline execution.
  """
  def assign(ctx, key, value) do
    %{ctx | assigns: Map.put(ctx.assigns, key, value)}
  end

  @doc """
  Record a routing error without halting execution.
  """
  def add_error(ctx, error) do
    %{ctx | errors: [error | ctx.errors]}
  end

  @doc """
  Immediately halt pipeline execution.
  """
  def halt(ctx) do
    %{ctx | halted: true}
  end

  # -------------------------
  # VALIDATION HELPERS
  # -------------------------

  @doc """
  Check if HTTP route is allowed by manifest.
  """
  def http_allowed?(%__MODULE__{manifest: manifest, path: path, method: method}) do
    routes = get_in(manifest, [:http]) || %{}

    case Map.get(routes, path) do
      nil -> false
      methods -> method in methods
    end
  end

  @doc """
  Check if domain is allowed.
  """
  def domain_allowed?(%__MODULE__{manifest: manifest, event: event}) do
    domains = Map.get(manifest, :domains, [])

    domains == [] or event.host in domains
  end

  @doc """
  Check if WS topic is allowed.
  """
  def ws_allowed?(%__MODULE__{manifest: manifest, event: event}) do
    topics = get_in(manifest, [:ws, :topics]) || []

    Enum.any?(topics, fn pattern ->
      topic_match?(pattern, event.path)
    end)
  end

  # -------------------------
  # INTERNAL HELPERS
  # -------------------------

  defp normalize_manifest(%{} = manifest), do: manifest
  defp normalize_manifest(_), do: %{}

  defp topic_match?(pattern, topic) when is_binary(pattern) and is_binary(topic) do
    cond do
      pattern == topic -> true
      String.ends_with?(pattern, "*") ->
        prefix = String.trim_trailing(pattern, "*")
        String.starts_with?(topic, prefix)

      true ->
        false
    end
  end
end