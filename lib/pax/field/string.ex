defmodule Pax.Field.String do
  @opts_schema NimbleOptions.new!(
                 truncate: [
                   type: {:or, [:pos_integer, nil]},
                   default: nil,
                   doc: "The length to truncate the value to when rendering."
                 ]
               )

  @moduledoc """
  A field type for string values, edited with a text input.

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
  def render(_opts, nil), do: nil

  def render(%{truncate: truncate}, value) when not is_nil(truncate) do
    value
    |> to_string()
    |> Pax.Util.String.truncate(truncate)
  end

  def render(_opts, value) do
    to_string(value)
  end

  @impl Pax.Field.Type
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.pax_field_control field={@field} form_field={@form_field} type="text" />
    """
  end
end
