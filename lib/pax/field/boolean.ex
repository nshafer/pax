defmodule Pax.Field.Boolean do
  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(_mod, opts) do
    # TODO: add formatting options: human, scientific, etc
    %{
      true: Keyword.get(opts, true, "True"),
      false: Keyword.get(opts, false, "False")
    }
  end

  @impl Pax.Field.Type
  def render(%{true: true_value, false: false_value}, value) do
    (value && true_value) || false_value
  end

  @impl Pax.Field.Type
  def input(%{true: true_value, false: false_value}, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field,
      true_value: true_value,
      false_value: false_value
    }

    ~H"""
    <Pax.Field.Components.field_control
      field={@field}
      form_field={@form_field}
      type="checkbox"
      true_value={@true_value}
      false_value={@false_value}
    />
    """
  end
end
