defmodule Pax.Field.Datetime do
  @opts_schema NimbleOptions.new!(
                 format: [
                   type: {:or, [:string, nil]},
                   default: nil,
                   doc: """
                   The `Calendar.strftime/2` format to render the value with. When not given, the date and time are
                   rendered separately with `:date_format` and `:time_format`.
                   """
                 ],
                 date_format: [
                   type: :string,
                   default: "%a, %B %d, %Y",
                   doc: "The `Calendar.strftime/2` format to render the date with."
                 ],
                 time_format: [
                   type: :string,
                   default: "%I:%M %p",
                   doc: "The `Calendar.strftime/2` format to render the time with."
                 ]
               )

  @moduledoc """
  A field type for `NaiveDateTime` and `DateTime` values, edited with a datetime-local input.

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

  def render(%{format: format}, value) when not is_nil(format) do
    Calendar.strftime(value, format)
  end

  def render(%{date_format: date_format, time_format: time_format}, value) do
    assigns = %{
      date: Calendar.strftime(value, date_format),
      time: Calendar.strftime(value, time_format)
    }

    ~H"""
    <span>{@date}</span>
    <span>{@time}</span>
    """
  end

  @impl Pax.Field.Type
  def input(_opts, field, form_field) do
    assigns = %{
      field: field,
      form_field: form_field
    }

    ~H"""
    <Pax.Field.Components.pax_field_control field={@field} form_field={@form_field} type="datetime-local" />
    """
  end
end
