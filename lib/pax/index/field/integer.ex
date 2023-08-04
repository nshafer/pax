defmodule Pax.Index.Field.Integer do
  @behaviour Pax.Index.Field

  @impl Pax.Index.Field
  def init(_mod, _opts) do
    # TODO: add formatting options: human, scientific, etc
    # TODO: add base option
    %{}
  end

  @impl Pax.Index.Field
  def render(_opts, nil), do: nil

  def render(_opts, value) do
    Integer.to_string(value)
  end
end
