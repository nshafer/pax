defmodule Pax.Field.Components do
  use Phoenix.Component

  attr :field, :any, required: true
  attr :object, :map, required: true

  def display(assigns) do
    case Pax.Field.link(assigns.field, assigns.object) do
      nil -> display_as_text(assigns)
      link -> display_as_link(assign(assigns, link: link))
    end
  end

  attr :field, :any, required: true
  attr :object, :map, required: true

  def display_as_text(assigns) do
    ~H"""
    <%= Pax.Field.render(@field, @object) %>
    """
  end

  attr :field, :any, required: true
  attr :object, :map, required: true
  attr :link, :string, required: true

  def display_as_link(assigns) do
    ~H"""
    <.link class="font-bold underline" navigate={@link}>
      <%= Pax.Field.render(@field, @object) %>
    </.link>
    """
  end
end
