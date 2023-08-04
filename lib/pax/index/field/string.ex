defmodule Pax.Index.Field.String do
  @behaviour Pax.Index.Field

  @impl Pax.Index.Field
  def init(_mod, _opts) do
    # TODO: add length limit
    %{}
  end

  @impl Pax.Index.Field
  def render(_opts, nil), do: nil

  def render(_opts, value) do
    to_string(value)
  end
end
