defmodule Pax.Field.Date do
  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(_mod, opts) do
    %{
      format: Keyword.get(opts, :format, "%a, %B %d, %Y")
    }
  end

  @impl Pax.Field.Type
  def render(_opts, nil), do: nil

  def render(%{format: format}, value) do
    Calendar.strftime(value, format)
  end

  @impl Pax.Field.Type
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.field_control field={@field} form_field={@form_field} type="date" />
    """
  end
end
