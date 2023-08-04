defmodule Pax.Index.Components do
  use Phoenix.Component

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component

      attr(:pax_module, :atom, required: true)
      attr(:objects, :list, required: true)
      attr(:class, :string, default: nil)

      def pax_index(var!(assigns)) do
        ~H"""
        <div id="pax" class={["pax pax-index", @class]} phx-hook="PaxHook">
          <.pax_table pax_module={@pax_module} objects={@objects} />
        </div>
        """
      end

      attr(:pax_module, :atom, required: true)
      attr(:objects, :list, required: true)
      attr(:class, :string, default: nil)

      def pax_table(var!(assigns)) do
        ~H"""
        <div class="overflow-auto">
          <table class={[
            "pax-table border-collapse table-auto w-full text-sm",
            @class
          ]}>
            <thead class="pax-table-head after:table-row after:h-2">
              <.pax_table_head pax_module={@pax_module} />
            </thead>
            <tbody class="pax-table-body">
              <%= for object <- @objects do %>
                <.pax_table_row pax_module={@pax_module} object={object} />
              <% end %>
            </tbody>
          </table>
        </div>
        """
      end

      attr(:pax_module, :atom, required: true)
      attr(:class, :string, default: nil)

      def pax_table_head(var!(assigns)) do
        ~H"""
        <tr>
          <%= for field <- Pax.Index.Live.fields(@pax_module) do %>
            <th class={[
              "pax-table-head-cell px-2 py-2 font-medium text-left text-neutral-600 dark:text-neutral-400",
              "bg-neutral-200 dark:bg-neutral-800",
              "border-b border-b-neutral-300 dark: dark:border-b-neutral-700",
              @class
            ]}>
              <%= Pax.Index.Field.title(@pax_module, field) %>
            </th>
          <% end %>
        </tr>
        """
      end

      attr(:pax_module, :atom, required: true)
      attr(:object, :any, required: true)
      attr(:class, :string, default: nil)

      def pax_table_row(var!(assigns)) do
        ~H"""
        <tr class={["pax-table-row", @class]}>
          <%= for field <- Pax.Index.Live.fields(@pax_module) do %>
            <.pax_table_cell pax_module={@pax_module} field={field} object={@object} />
          <% end %>
        </tr>
        """
      end

      attr(:pax_module, :atom, required: true)
      attr(:field, :any, required: true)
      attr(:object, :any, required: true)
      attr(:class, :string, default: nil)

      def pax_table_cell(var!(assigns)) do
        ~H"""
        <td class={["pax-table-cell px-2 py-1", @class]}>
          <%= Pax.Index.Field.render(@pax_module, @field, @object) %>
        </td>
        """
      end

      defoverridable pax_index: 1,
                     pax_table: 1,
                     pax_table_head: 1,
                     pax_table_row: 1,
                     pax_table_cell: 1
    end
  end
end
