defmodule Pax.Field.Datetime do
  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    %{
      format: Keyword.get(opts, :format, nil),
      date_format: Keyword.get(opts, :format, "%a, %B %d, %Y"),
      time_format: Keyword.get(opts, :format, "%I:%M %p")
    }
  end

  @impl Pax.Field.Type
  def render(_opts, nil), do: nil

  def render(%{format: format}, value) when not is_nil(format) do
    Calendar.strftime(value, format)
  end

  def render(%{date_format: date_format, time_format: time_format}, value) do
    assigns = %{
      date: Calendar.strftime(value, date_format),
      time: Calendar.strftime(value, time_format)
    }

    ~H"""
    <span>{@date}</span>
    <span>{@time}</span>
    """
  end

  @impl Pax.Field.Type
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.pax_field_control field={@field} form_field={@form_field} type="datetime-local" />
    """
  end
end
