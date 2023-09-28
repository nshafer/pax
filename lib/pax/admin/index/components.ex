defmodule Pax.Admin.Index.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components
  import Pax.Index.Components

  attr :pax, :map, required: true
  attr :resource, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def index(assigns) do
    ~H"""
    <div class={["pax pax-index", @class]}>
      <.pax_header pax={@pax}>
        <:title>
          <%= @pax.plural_name %>
        </:title>

        <:action :if={@pax.new_path}>
          <.pax_button navigate={@pax.new_path}>New</.pax_button>
        </:action>
      </.pax_header>

      <.table fields={@pax.fields} objects={@objects}>
        <:header :let={field}>
          <.field_label field={field} />
        </:header>
        <:cell :let={{field, object}}>
          <.field_link_or_text field={field} object={object} opts={[resource: @resource]} />
        </:cell>
      </.table>
    </div>
    """
  end
end
