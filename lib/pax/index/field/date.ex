defmodule Pax.Index.Field.Date do
  @behaviour Pax.Index.Field

  @impl Pax.Index.Field
  def init(_mod, opts) do
    %{
      format: Keyword.get(opts, :format, "%a, %B %d, %Y")
    }
  end

  @impl Pax.Index.Field
  def render(_opts, nil), do: nil

  def render(%{format: format}, value) do
    Calendar.strftime(value, format)
  end
end
