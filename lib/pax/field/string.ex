defmodule Pax.Field.String do
  use Phoenix.Component
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

  @impl Pax.Field
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.field_control field={@field} form_field={@form_field} type="text" />
    """
  end
end
