defmodule Pax.Admin.Dashboard.Components do
  use Phoenix.Component

  attr :pax_admin_mod, :atom, required: true
  attr :pax_resource_tree, :list, required: true

  def toc(assigns) do
    ~H"""
    <ul class="list-disc ml-4">
      <.toc_section :for={entry <- @pax_resource_tree} entry={entry} pax_admin_mod={@pax_admin_mod} />
    </ul>
    """
  end

  attr :entry, :map, required: true
  attr :pax_admin_mod, :atom, required: true

  def toc_section(%{entry: %{section: nil}} = assigns) do
    ~H"""
    <%= for resource <- @entry.resources do %>
      <li>
        <.link navigate={@pax_admin_mod.resource_index_path(nil, resource.path)}>
          <%= resource.title %>
        </.link>
      </li>
    <% end %>
    """
  end

  def toc_section(assigns) do
    ~H"""
    <li>
      <h2><%= @entry.section.title %></h2>
      <ul class="list-disc ml-4">
        <%= for resource <- @entry.resources do %>
          <li>
            <.link navigate={@pax_admin_mod.resource_index_path(@entry.section.path, resource.path)}>
              <%= resource.title %>
            </.link>
          </li>
        <% end %>
      </ul>
    </li>
    """
  end
end
