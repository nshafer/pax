defmodule Pax.Field.Date do
  @behaviour Pax.Field

  @impl Pax.Field
  def init(_mod, opts) do
    %{
      format: Keyword.get(opts, :format, "%a, %B %d, %Y")
    }
  end

  @impl Pax.Field
  def render(_opts, nil), do: nil

  def render(%{format: format}, value) do
    Calendar.strftime(value, format)
  end
end
