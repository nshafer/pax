defmodule Pax.Field.Integer do
  @opts_schema NimbleOptions.new!([])

  @moduledoc """
  A field type for integer values, edited with a numeric text input. It takes no options.

  ## Options

  #{NimbleOptions.docs(@opts_schema)}
  """

  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    # TODO: add formatting options: human, scientific, etc
    # TODO: add base option
    opts
    |> Pax.Options.validate!(@opts_schema, "field type #{inspect(__MODULE__)}")
    |> Map.new()
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
    <Pax.Field.Components.pax_field_control
      field={@field}
      form_field={@form_field}
      type="text"
      inputmode="numeric"
      pattern="[0-9]*"
    />
    """
  end
end
