defmodule Pax.Index.Components do
  use Phoenix.Component

  attr :fields, :list, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def index(assigns) do
    ~H"""
    <div class={["pax-index", @class]}>
      <Pax.Index.Components.table fields={@fields} objects={@objects} />
    </div>
    """
  end

  attr :fields, :list, required: true
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
            <%= for field <- @fields do %>
              <th class="pax-index-table-header">
                <Pax.Field.Components.title field={field} />
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr class="pax-index-table-row">
              <%= for field <- @fields do %>
                <td class="pax-index-table-datacell">
                  <Pax.Field.Components.display field={field} object={object} />
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
