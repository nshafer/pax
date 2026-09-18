defmodule Pax.Field.Date do
  @opts_schema NimbleOptions.new!(
                 format: [
                   type: :string,
                   default: "%a, %B %d, %Y",
                   doc: "The `Calendar.strftime/2` format to render the date with."
                 ]
               )

  @moduledoc """
  A field type for `Date` values, edited with a date input.

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
    <Pax.Field.Components.pax_field_control field={@field} form_field={@form_field} type="date" />
    """
  end
end
