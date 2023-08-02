defmodule Pax.Index.Components do
  use Phoenix.Component

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component

      def pax_index(var!(assigns)) do
        ~H"""
        <ul id="pax-index" phx-hook="PaxHook">
          <%= for object <- @objects do %>
            <.pax_row object={object} />
          <% end %>
        </ul>
        """
      end

      def pax_row(var!(assigns)) do
        ~H"""
        <li class="-bg-slate-800 -text-slate-50">
          <%= @object.id %> - <%= @object.name %>
        </li>
        """
      end

      defoverridable pax_index: 1, pax_row: 1
    end
  end
end
