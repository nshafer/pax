defmodule Pax.Field.Integer do
  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(_opts) do
    # TODO: add formatting options: human, scientific, etc
    # TODO: add base option
    %{}
  end

  @impl Pax.Field.Type
  def render(_opts, nil), do: nil

  def render(_opts, value) do
    Integer.to_string(value)
  end

  @impl Pax.Field.Type
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.field_control
      field={@field}
      form_field={@form_field}
      type="text"
      inputmode="numeric"
      pattern="[0-9]*"
    />
    """
  end
end
