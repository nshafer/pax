defmodule Pax.Admin.Dashboard.Components do
  use Phoenix.Component

  attr :admin, :map, required: true

  def toc(assigns) do
    ~H"""
    <ul class="list-disc ml-4">
      <%= for entry <- @admin.resource_tree do %>
        <.toc_section entry={entry} admin={@admin} />
      <% end %>
    </ul>
    """
  end

  attr :admin, :map, required: true
  attr :entry, :map, required: true

  def toc_section(assigns) do
    ~H"""
    <%= if @entry.section == nil do %>
      <%= for resource <- @entry.resources do %>
        <li>
          <.link navigate={@admin.mod.resource_index_path(nil, resource.path)}>
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
              <.link navigate={@admin.mod.resource_index_path(@entry.section.path, resource.path)}>
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
