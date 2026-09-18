defmodule Pax.Field.Boolean do
  @opts_schema NimbleOptions.new!(
                 true: [type: :string, default: "True", doc: "The text shown for true values."],
                 false: [type: :string, default: "False", doc: "The text shown for false and nil values."]
               )

  @moduledoc """
  A field type for boolean values, rendered as text and edited with a checkbox.

  ## Options

  #{NimbleOptions.docs(@opts_schema)}
  """

  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    opts
    |> Pax.Options.validate!(@opts_schema, "field type #{inspect(__MODULE__)}")
    |> Map.new()
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
    <Pax.Field.Components.pax_field_control
      field={@field}
      form_field={@form_field}
      type="checkbox"
      true_value={@true_value}
      false_value={@false_value}
    />
    """
  end
end
