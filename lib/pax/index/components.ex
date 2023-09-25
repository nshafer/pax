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

      <.table pax={@pax} objects={@objects} />
    </div>
    """
  end

  attr :pax, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  # TODO: refactor this to not take pax, and instead take fields and use slots for the headers and cells
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
                  <.field_link_or_text field={field} object={object} />
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
