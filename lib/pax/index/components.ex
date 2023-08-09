defmodule Pax.Index.Components do
  use Phoenix.Component

  attr :fields, :list, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def index(assigns) do
    ~H"""
    <div id="pax" class={["pax pax-index", @class]} phx-hook="PaxHook">
      <Pax.Index.Components.table fields={@fields} objects={@objects} />
    </div>
    """
  end

  attr :fields, :list, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def table(assigns) do
    ~H"""
    <div class="overflow-auto">
      <table class={[
        "pax-table border-collapse table-auto w-full text-sm",
        @class
      ]}>
        <thead class="after:table-row after:h-2">
          <tr>
            <%= for field <- @fields do %>
              <th class={[
                "px-2 py-2 align-bottom",
                "font-medium text-left text-neutral-600 dark:text-neutral-400",
                "bg-neutral-200 dark:bg-neutral-800",
                "border-b border-b-neutral-300 dark: dark:border-b-neutral-700"
              ]}>
                <%= Pax.Field.title(field) %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr>
              <%= for field <- @fields do %>
                <td class="px-2 py-1">
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
