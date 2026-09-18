defmodule Pax.Field.Float do
  @opts_schema NimbleOptions.new!(
                 round: [
                   type: {:or, [:integer, nil]},
                   default: nil,
                   doc: "The number of decimal places to round the value to when rendering."
                 ]
               )

  @moduledoc """
  A field type for float values, edited with a numeric text input.

  ## Options

  #{NimbleOptions.docs(@opts_schema)}
  """

  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    # TODO: add formatting options: human, scientific, etc
    opts = Pax.Options.validate!(opts, @opts_schema, "field type #{inspect(__MODULE__)}")
    %{round: opts[:round]}
  end

  @impl Pax.Field.Type
  def render(_opts, nil), do: nil

  def render(%{round: round}, value) when not is_nil(round) do
    value
    |> Float.round(round)
    |> Float.to_string()
  end

  def render(_opts, value) do
    Float.to_string(value)
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
      pattern="[0-9\.\-]*"
    />
    """
  end
end
