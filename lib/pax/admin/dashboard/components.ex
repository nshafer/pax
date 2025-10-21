defmodule Pax.Admin.Dashboard.Components do
  use Phoenix.Component

  # attr :pax_admin, Pax.Admin, required: true

  # def toc(assigns) do
  #   ~H"""
  #   <ul class="list-disc ml-4">
  #     <%= for entry <- @pax_admin.resource_tree do %>
  #       <.toc_section entry={entry} pax_admin={@pax_admin} />
  #     <% end %>
  #   </ul>
  #   """
  # end

  # attr :pax_admin, Pax.Admin, required: true
  # attr :entry, :map, required: true

  # def toc_section(assigns) do
  #   ~H"""
  #   <%= if @entry.section == nil do %>
  #     <%= for resource <- @entry.resources do %>
  #       <li>
  #         <.link navigate={Pax.Admin.resource_index_path(@pax_admin.admin_mod, nil, resource)}>
  #           <%= resource.label %>
  #         </.link>
  #       </li>
  #     <% end %>
  #   <% else %>
  #     <li>
  #       <h2><%= @entry.section.label %></h2>
  #       <ul class="list-disc ml-4">
  #         <%= for resource <- @entry.resources do %>
  #           <li>
  #             <.link navigate={Pax.Admin.resource_index_path(@pax_admin.admin_mod, @entry.section, resource)}>
  #               <%= resource.label %>
  #             </.link>
  #           </li>
  #         <% end %>
  #       </ul>
  #     </li>
  #   <% end %>
  #   """
  # end
end
