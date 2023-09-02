defmodule Pax.Admin.Index.Components do
  use Phoenix.Component

  attr :pax, :map, required: true
  attr :resource, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def index(assigns) do
    ~H"""
    <div class={["pax pax-index", @class]}>
      <Pax.Admin.Index.Components.table pax={@pax} resource={@resource} objects={@objects} />
    </div>
    """
  end

  attr :pax, :map, required: true
  attr :resource, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

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
                <Pax.Field.Components.title field={field} />
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr class="pax-index-table-row">
              <%= for field <- @pax.fields do %>
                <td class="pax-index-table-datacell">
                  <Pax.Field.Components.display field={field} object={object} opts={[resource: @resource]} />
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
