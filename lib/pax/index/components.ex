defmodule Pax.Index.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components

  attr :pax, :map, required: true
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
          <.field_link_or_text field={field} object={object} />
        </:cell>
      </.table>
    </div>
    """
  end

  attr :fields, :list, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  slot :header, required: true
  slot :cell, required: true

  def table(assigns) do
    ~H"""
    <div class="pax-table-wrapper">
      <table class={["pax-index-table", @class]}>
        <thead class="pax-index-table-head">
          <tr class="pax-index-table-head-row">
            <%= for field <- @fields do %>
              <th class="pax-index-table-header">
                <%= render_slot(@header, field) %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr class="pax-index-table-row">
              <%= for field <- @fields do %>
                <td class="pax-index-table-datacell">
                  <%= render_slot(@cell, {field, object}) %>
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
