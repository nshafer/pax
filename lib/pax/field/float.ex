defmodule Pax.Field.Float do
  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    # TODO: add formatting options: human, scientific, etc
    %{
      round: Keyword.get(opts, :round, 5)
    }
  end

  @impl Pax.Field.Type
  def render(_opts, nil), do: nil

  def render(%{round: round}, value) do
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
