defmodule ExServiceMeshRouter.Utils.Time do
  @moduledoc """
  Time utilities for the service mesh router.

  Used for:
  - trace timestamps
  - manifest versioning
  - sync scheduling
  - retry backoff coordination
  - protocol framing
  """

  @doc """
  Returns current unix time in milliseconds.
  """
  def now_ms do
    System.system_time(:millisecond)
  end

  @doc """
  Returns current unix time in seconds.
  """
  def now_sec do
    System.system_time(:second)
  end

  @doc """
  Generates ISO8601 timestamp (UTC).
  """
  def iso8601 do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  @doc """
  Adds milliseconds to current time and returns future timestamp.
  Useful for scheduling retry/backoff logic.
  """
  def future_ms(ms) when is_integer(ms) do
    now_ms() + ms
  end

  @doc """
  Exponential backoff helper (bounded).
  Used by WS reconnect + sync retries.
  """
  def backoff(attempt, base \\ 250, max \\ 30_000)
      when is_integer(attempt) do
    (base * :math.pow(2, attempt))
    |> round()
    |> min(max)
  end

  @doc """
  Converts ms duration to seconds.
  """
  def ms_to_sec(ms), do: div(ms, 1000)

  @doc """
  Simple monotonic timestamp (safe for ordering events).
  """
  def monotonic do
    System.monotonic_time(:millisecond)
  end
end