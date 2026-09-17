defmodule PaxTest.Owner do
  @moduledoc """
  A per-test registry, so async tests can configure shared test LiveViews, resources and the fake repo.

  Values are keyed by the pid of the test process. Code running inside a LiveView finds the test process through
  `$callers`, which `Phoenix.LiveViewTest` sets on every LiveView process it starts. The initial (disconnected)
  render runs in the test process itself.
  """

  @table __MODULE__

  def start do
    :ets.new(@table, [:named_table, :public, :set])
  end

  @doc "The test process that owns the current process."
  def owner do
    List.last([self() | Process.get(:"$callers", [])])
  end

  @doc "Store `value` under `key` for the current test."
  def put(key, value) do
    :ets.insert(@table, {{self(), key}, value})
    :ok
  end

  @doc "Store every key/value pair for the current test."
  def put_all(keyword) do
    Enum.each(keyword, fn {key, value} -> put(key, value) end)
  end

  @doc "Get the value under `key` for the owning test."
  def get(key, default \\ nil) do
    case :ets.lookup(@table, {owner(), key}) do
      [{_, value}] -> value
      [] -> default
    end
  end

  @doc """
  Call the function stored under `key` with `args`. Any other stored value is returned as is, and `default` is
  returned if the test didn't store anything.
  """
  def call(key, args, default) do
    case get(key) do
      fun when is_function(fun, length(args)) -> apply(fun, args)
      nil -> default
      value -> value
    end
  end

  @doc "Send a message to the owning test process."
  def notify(message) do
    send(owner(), message)
    :ok
  end
end
