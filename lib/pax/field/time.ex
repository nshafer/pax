defmodule Pax.Field.Time do
  use Phoenix.Component
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

  @impl Pax.Field
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.field_control field={@field} form_field={@form_field} type="time" />
    """
  end
end
