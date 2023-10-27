defmodule Pax.Admin.Components do
  use Phoenix.Component

  attr :pax, Pax.Interface.Context, default: nil
  attr :pax_admin, Pax.Admin.Context, required: true

  def breadcrumbs(assigns) do
    ~H"""
    <div class="px-4 py-1 text-sm">
      <%= if @pax_admin.site_mod do %>
        <.link navigate={@pax_admin.site_mod.dashboard_path()}>
          Dashboard
        </.link>

        <%= if @pax_admin.resource do %>
          <span class="mx-1">❯</span>
          <%= if @pax_admin.resource.section do %>
            <%= @pax_admin.resource.section.label %>
            <span class="mx-1">❯</span>
          <% end %>
          <.link navigate={@pax_admin.site_mod.resource_index_path(@pax_admin.resource.section, @pax_admin.resource)}>
            <%= @pax_admin.resource.label %>
          </.link>
          <%= if @pax.object_name do %>
            <span class="mx-1">❯</span>
            <%= @pax.object_name %>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true

  def sidebar_menu(assigns) do
    dbg(assigns.pax_admin.resource)

    ~H"""
    <div class="group/sidebar_menu">
      <%= for entry <- resource_tree(@pax_admin.resources) do %>
        <%= if entry.section do %>
          <.sidebar_section pax_admin={@pax_admin} section={entry.section} resources={entry.resources} />
        <% else %>
          <%= for resource <- entry.resources do %>
            <.sidebar_resource pax_admin={@pax_admin} resource={resource} />
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true
  attr :section, Pax.Admin.Section, default: nil
  attr :resources, :list, default: []

  def sidebar_section(assigns) do
    active? = assigns.pax_admin.resource && assigns.section == assigns.pax_admin.resource.section
    assigns = Map.put(assigns, :active?, active?)

    ~H"""
    <div class="group/sidebar_section relative">
      <input type="checkbox" class="peer hidden" id={"section_toggle_#{@section.name}"} checked={@active?} />
      <label
        for={"section_toggle_#{@section.name}"}
        id={"section_button_#{@section.name}"}
        class={[
          "block w-full cursor-pointer select-none",
          "pl-4 pr-8 py-2 leading-5 text-left",
          "hover:bg-zinc-200 dark:hover:bg-zinc-800",
          "border-l-8 border-transparent",
          "peer-checked:border-zinc-300 dark:peer-checked:border-zinc-700"
        ]}
      >
        <%= @section.label %>
      </label>
      <div class="absolute top-[6px] right-4 peer-checked:rotate-90 transition-transform">
        <i class="fa-solid fa-chevron-right "></i>
      </div>
      <div
        id={"section_submenu_#{@section.name}"}
        class="grid grid-rows-[0fr] peer-checked:grid-rows-[1fr] transition-[grid-template-rows] ease-in-out"
      >
        <div class="overflow-hidden">
          <%= for resource <- @resources do %>
            <.sidebar_resource pax_admin={@pax_admin} section={@section} resource={resource} indent="pl-8" />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true
  attr :section, Pax.Admin.Section, default: nil
  attr :resource, Pax.Admin.Resource, required: true
  attr :indent, :string, default: "pl-4"

  def sidebar_resource(assigns) do
    active? = assigns.resource == assigns.pax_admin.resource
    assigns = Map.put(assigns, :active?, active?)

    ~H"""
    <.link
      class={[
        "block py-2 pr-4 ",
        @indent,
        "leading-5 truncate",
        "hover:bg-zinc-200 dark:hover:bg-zinc-800",
        "border-l-8",
        @active? &&
          "font-bold border-sky-900 dark:border-sky-950 bg-sky-100 hover:bg-sky-200 dark:bg-sky-925 dark:hover:bg-sky-900",
        !@active? && "border-transparent"
      ]}
      navigate={Pax.Admin.Site.resource_index_path(@pax_admin.site_mod, @section, @resource)}
    >
      <%= @resource.label %>
    </.link>
    """
  end

  slot :title, required: true
  slot :marquee
  slot :tools

  slot :tool

  def header(assigns) do
    ~H"""
    <div class="flex gap-8 items-center bg-zinc-50 dark:bg-zinc-800 border-b p-4 mb-4">
      <div class="text-2xl mr-auto leading-5 ">
        <%= render_slot(@title) %>
      </div>

      <div :if={@marquee != []} class="mx-auto">
        <%= render_slot(@marquee) %>
      </div>

      <div class="flex flex-wrap gap-2 justify-end items-center ml-auto">
        <%= if @tools != [] do %>
          <%= render_slot(@tools) %>
        <% else %>
          <div :for={tool <- @tool}>
            <%= render_slot(tool) %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Transform a list of resources into a list of sections, each with a list of resources
  defp resource_tree(resources) do
    Enum.reduce(resources, {[], nil}, fn
      resource, {[], nil} ->
        {[%{section: resource.section, resources: [resource]}], resource.section}

      %{section: current_section} = resource, {[curr | rest], current_section} ->
        {[%{curr | resources: [resource | curr.resources]} | rest], current_section}

      resource, {acc, _current_section} ->
        {[%{section: resource.section, resources: [resource]} | acc], resource.section}
    end)
    |> elem(0)
    |> Enum.map(fn %{resources: resources} = entry -> %{entry | resources: Enum.reverse(resources)} end)
    |> Enum.reverse()
  end
end
