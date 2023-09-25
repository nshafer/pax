defmodule Pax.Admin.Index.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components

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

      <.table pax={@pax} resource={@resource} objects={@objects} />
    </div>
    """
  end

  attr :pax, :map, required: true
  attr :resource, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  # TODO: put resource in the 'pax' assign instead of passing it around, pass the pax map to field components and
  # their callbacks?
  def table(assigns) do
    ~H"""
    <div class="pax-table-wrapper">
      <table class={[
        "pax-index-table",
        @class
      ]}>
        <thead class="pax-index-table-head">
          <tr class="pax-index-table-head-row">
            <%= for field <- @pax.fields do %>
              <th class="pax-index-table-header">
                <.field_label field={field} />
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr class="pax-index-table-row">
              <%= for field <- @pax.fields do %>
                <td class="pax-index-table-datacell">
                  <.field_link_or_text field={field} object={object} opts={[resource: @resource]} />
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
