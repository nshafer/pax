defmodule Pax.Field.Time do
  @opts_schema NimbleOptions.new!(
                 format: [
                   type: :string,
                   default: "%I:%M %p",
                   doc: "The `Calendar.strftime/2` format to render the time with."
                 ]
               )

  @moduledoc """
  A field type for `Time` values, edited with a time input.

  ## Options

  #{NimbleOptions.docs(@opts_schema)}
  """

  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    opts = Pax.Options.validate!(opts, @opts_schema, "field type #{inspect(__MODULE__)}")

    Map.new(opts)
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
    <Pax.Field.Components.pax_field_control field={@field} form_field={@form_field} type="time" />
    """
  end
end
