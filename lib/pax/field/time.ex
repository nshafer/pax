defmodule Pax.Field.Time do
  @behaviour Pax.Field

  @impl Pax.Field
  def init(_mod, opts) do
    %{
      format: Keyword.get(opts, :format, "%I:%M %p")
    }
  end

  @impl Pax.Field
  def render(_opts, nil), do: nil

  def render(%{format: format}, value) do
    Calendar.strftime(value, format)
  end
end
