defmodule ExServiceMeshRouter.Routing.TopicRouter do
  @moduledoc """
  WebSocket topic routing layer for the service mesh.

  Responsibilities:
  - Resolve WS target app via AutoRegistry
  - Validate topic against manifest
  - Normalize topic routing context
  - Forward WS event into pipeline engine
  """

  alias ExServiceMeshRouter.Core.{MeshEvent, EventBus}
  alias ExServiceMeshRouter.Routing.Context
  alias ExServiceMeshRouter.Discovery.{AutoRegistry, ManifestStore}

  # -------------------------
  # ENTRY POINT
  # -------------------------

  @doc """
  Route a WS message to the appropriate Phoenix app.
  """
  def route(app, topic, payload, meta \\ %{}) do
    with {:ok, endpoint} <- AutoRegistry.lookup(app),
         {:ok, manifest} <- ManifestStore.get(app),
         true <- topic_allowed?(manifest, topic) do

      event =
        MeshEvent.new(%{
          type: :ws,
          app: app,
          path: topic,
          headers: meta,
          payload: payload,
          conn_ref: Map.get(meta, :conn_ref)
        })

      ctx =
        Context.new(event, app, endpoint, manifest)
        |> Context.assign(:topic, topic)

      EventBus.emit(event)

      {:ok, ctx}

    else
      false ->
        {:error, :topic_not_allowed}

      :error ->
        {:error, :app_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -------------------------
  # TOPIC VALIDATION
  # -------------------------

  defp topic_allowed?({:ok, %{manifest: manifest}}, topic) do
    ws_topics = get_in(manifest, [:ws, :topics]) || []

    Enum.any?(ws_topics, fn pattern ->
      topic_match?(pattern, topic)
    end)
  end

  defp topic_allowed?(:error, _topic), do: false

  # -------------------------
  # PATTERN MATCHING
  # -------------------------

  @doc """
  Supports:
  - exact match: "room:lobby"
  - wildcard match: "room:*"
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
end