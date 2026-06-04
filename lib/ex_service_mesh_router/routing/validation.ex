defmodule ExServiceMeshRouter.Routing.Validation do
  @moduledoc """
  Central validation layer for mesh routing decisions.

  Responsibilities:
  - Validate HTTP routes against manifests
  - Validate WS topics against manifests
  - Validate domain access rules
  - Provide unified error reasons for routing decisions
  """

  alias ExServiceMeshRouter.Routing.Context

  # -------------------------
  # PUBLIC API
  # -------------------------

  @doc """
  Validate a full routing context.

  Returns:
  - :ok
  - {:error, reason}
  """
  def validate(%Context{} = ctx) do
    with :ok <- validate_domain(ctx),
         :ok <- validate_by_type(ctx) do
      :ok
    end
  end

  # -------------------------
  # TYPE DISPATCH
  # -------------------------

  defp validate_by_type(%Context{type: :http} = ctx),
       do: validate_http(ctx)

  defp validate_by_type(%Context{type: :ws} = ctx),
       do: validate_ws(ctx)

  defp validate_by_type(_),
       do: {:error, :unknown_event_type}

  # -------------------------
  # HTTP VALIDATION
  # -------------------------

  def validate_http(%Context{} = ctx) do
    routes = get_in(ctx.manifest, [:http]) || %{}

    case Map.get(routes, ctx.path) do
      nil ->
        {:error, :route_not_found}

      allowed_methods when is_list(allowed_methods) ->
        if ctx.method in allowed_methods do
          :ok
        else
          {:error, :method_not_allowed}
        end

      _ ->
        {:error, :invalid_manifest_http_definition}
    end
  end

  # -------------------------
  # WS VALIDATION
  # -------------------------

  def validate_ws(%Context{} = ctx) do
    topics = get_in(ctx.manifest, [:ws, :topics]) || []

    if Enum.any?(topics, fn pattern ->
      topic_match?(pattern, ctx.path)
    end) do
      :ok
    else
      {:error, :topic_not_allowed}
    end
  end

  # -------------------------
  # DOMAIN VALIDATION
  # -------------------------

  def validate_domain(%Context{} = ctx) do
    domains = Map.get(ctx.manifest, :domains, [])

    cond do
      domains == [] ->
        :ok

      ctx.event && ctx.event.host in domains ->
        :ok

      true ->
        {:error, :domain_not_allowed}
    end
  end

  # -------------------------
  # PATTERN MATCHING
  # -------------------------

  @doc """
  Supports:
  - exact match: "room:lobby"
  - wildcard: "room:*"
  """
  def topic_match?(pattern, topic)
      when is_binary(pattern) and is_binary(topic) do
    cond do
      pattern == topic ->
        true

      String.ends_with?(pattern, "*") ->
        prefix = String.trim_trailing(pattern, "*")
        String.starts_with?(topic, prefix)

      true ->
        false
    end
  end

  # -------------------------
  # ERROR NORMALIZATION
  # -------------------------

  @doc """
  Converts validation errors into stable atoms for logging / metrics.
  """
  def normalize_error({:error, reason}), do: reason
  def normalize_error(:ok), do: :ok
end