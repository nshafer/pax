defmodule Pax.Field.Datetime do
  @behaviour Pax.Field

  @impl Pax.Field
  def init(_mod, opts) do
    %{
      format: Keyword.get(opts, :format, nil),
      date_format: Keyword.get(opts, :format, "%a, %B %d, %Y"),
      time_format: Keyword.get(opts, :format, "%I:%M %p")
    }
  end

  @impl Pax.Field
  def render(_opts, nil), do: nil

  def render(%{format: format}, value) when not is_nil(format) do
    Phoenix.HTML.Tag.content_tag(:span, Calendar.strftime(value, format), style: "white-space: nowrap;")
  end

  def render(%{date_format: date_format, time_format: time_format}, value) do
    date = Calendar.strftime(value, date_format)
    time = Calendar.strftime(value, time_format)

    [
      Phoenix.HTML.Tag.content_tag(:span, date, style: "white-space: nowrap;"),
      " ",
      Phoenix.HTML.Tag.content_tag(:span, time, style: "white-space: nowrap;")
    ]
  end
end
