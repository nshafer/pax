defmodule Pax.Index.Field.Boolean do
  @behaviour Pax.Index.Field

  @impl Pax.Index.Field
  def init(_mod, opts) do
    # TODO: add formatting options: human, scientific, etc
    %{
      true: Keyword.get(opts, true, "true"),
      false: Keyword.get(opts, false, "false")
    }
  end

  @impl Pax.Index.Field
  def render(%{true: true_val, false: false_val}, value) do
    (value && true_val) || false_val
  end
end
