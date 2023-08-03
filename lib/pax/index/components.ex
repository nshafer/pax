defmodule Pax.Index.Components do
  use Phoenix.Component

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component

      attr :objects, :list, required: true
      attr :class, :string, default: nil

      def pax_index(var!(assigns)) do
        ~H"""
        <div id="pax" class={["pax pax-index", @class]} phx-hook="PaxHook">
          <ul>
            <%= for object <- @objects do %>
              <.pax_row object={object} />
            <% end %>
          </ul>
        </div>
        """
      end

      attr :object, :any, required: true

      def pax_row(var!(assigns)) do
        ~H"""
        <li>
          <span class="font-bold"><%= @object.id %></span> - <%= @object.name %>
        </li>
        """
      end

      defoverridable pax_index: 1, pax_row: 1
    end
  end
end
