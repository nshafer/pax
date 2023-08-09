defmodule Pax.Field.Float do
  @behaviour Pax.Field

  @impl Pax.Field
  def init(_mod, opts) do
    # TODO: add formatting options: human, scientific, etc
    %{
      round: Keyword.get(opts, :round)
    }
  end

  @impl Pax.Field
  def render(_opts, nil), do: nil

  def render(%{round: round}, value) do
    value
    |> Float.round(round)
    |> Float.to_string()
  end

  def render(_opts, value) do
    Float.to_string(value)
  end
end
