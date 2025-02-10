defmodule Pax.Field.String do
  use Phoenix.Component
  @behaviour Pax.Field.Type

  @impl Pax.Field.Type
  def init(opts) do
    %{
      truncate: Keyword.get(opts, :truncate, nil)
    }
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
