defmodule Pax.Admin.Dashboard.Components do
  use Phoenix.Component

  attr :admin_site, :map, required: true

  def toc(assigns) do
    ~H"""
    <ul class="list-disc ml-4">
      <%= for entry <- @admin_site.resource_tree do %>
        <.toc_section entry={entry} admin_site={@admin_site} />
      <% end %>
    </ul>
    """
  end

  attr :admin_site, :map, required: true
  attr :entry, :map, required: true

  def toc_section(assigns) do
    ~H"""
    <%= if @entry.section == nil do %>
      <%= for resource <- @entry.resources do %>
        <li>
          <.link navigate={Pax.Admin.Site.resource_index_path(@admin_site.mod, nil, resource)}>
            <%= resource.title %>
          </.link>
        </li>
      <% end %>
    <% else %>
      <li>
        <h2><%= @entry.section.title %></h2>
        <ul class="list-disc ml-4">
          <%= for resource <- @entry.resources do %>
            <li>
              <.link navigate={Pax.Admin.Site.resource_index_path(@admin_site.mod, @entry.section, resource)}>
                <%= resource.title %>
              </.link>
            </li>
          <% end %>
        </ul>
      </li>
    <% end %>
    """
  end
end
