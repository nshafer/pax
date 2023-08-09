defmodule Pax.Field.String do
  @behaviour Pax.Field

  @impl Pax.Field
  def init(_mod, _opts) do
    # TODO: add length limit
    %{}
  end

  @impl Pax.Field
  def render(_opts, nil), do: nil

  def render(_opts, value) do
    to_string(value)
  end
end
