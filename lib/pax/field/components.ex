defmodule Pax.Field.Components do
  use Phoenix.Component

  attr :field, :any, required: true

  def title(assigns) do
    ~H"""
    <span class="pax-field-title">
      <%= Pax.Field.title(@field) %>
    </span>
    """
  end

  attr :field, :any, required: true
  attr :object, :map, required: true
  attr :opts, :any, default: []

  def display(assigns) do
    case Pax.Field.link(assigns.field, assigns.object, assigns.opts) do
      nil -> display_as_text(assigns)
      link -> display_as_link(assign(assigns, link: link))
    end
  end

  attr :field, :any, required: true
  attr :object, :map, required: true

  def display_as_text(assigns) do
    ~H"""
    <span class="pax-field-text">
      <%= Pax.Field.render(@field, @object) %>
    </span>
    """
  end

  attr :field, :any, required: true
  attr :object, :map, required: true
  attr :link, :string, required: true

  def display_as_link(assigns) do
    ~H"""
    <.link class="pax-field-link" navigate={@link}>
      <%= Pax.Field.render(@field, @object) %>
    </.link>
    """
  end
end
