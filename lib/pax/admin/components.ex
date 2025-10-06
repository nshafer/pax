defmodule Pax.Admin.Components do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  import Pax.Components
  import Pax.Util.String

  @doc """
  Includes the Pax Admin CSS and JS assets. Should be included in the `<head>` of your
  admin layout, for example:
      <head>
        ...
        <Pax.Admin.Components.assets />
        ...
      </head>
  """
  @doc type: :component
  attr :at, :string, default: "/pax"

  def assets(assigns) do
    ~H"""
    <link phx-track-static rel="stylesheet" href={Pax.Admin.Assets.asset_path(:css, @at, "pax_admin.css")} />
    <script defer phx-track-static type="text/javascript" src={Pax.Admin.Assets.asset_path(:js, @at, "pax_admin.js")}>
    </script>
    """
  end

  @doc """
  Includes the FontAwesome CSS asset for use in admin pages. Should be included in the `<head>` of your
  admin layout, for example:
      <head>
        ...
        <Pax.Admin.Components.fontawesome />
        ...
      </head>
  """

  @doc type: :component
  attr :at, :string, default: "/pax"

  def fontawesome(assigns) do
    ~H"""
    <link phx-track-static rel="stylesheet" href={Pax.Assets.static_path(@at, "fontawesome/css/all.min.css")} />
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true

  def admin_title(assigns) do
    ~H"""
    <div class="admin-title">
      <%= if @pax_admin.config.title != nil do %>
        {@pax_admin.config.title}
      <% else %>
        <i class="fa-solid fa-fire-flame-curved"></i> Pax Admin
      <% end %>
    </div>
    """
  end

  slot :primary
  slot :secondary

  def admin_header(assigns) do
    ~H"""
    <div class="admin-header">
      <div :if={@primary != []} class="admin-header-section">
        {render_slot(@primary)}
      </div>
      <div :if={@secondary != []} class="admin-header-section">
        {render_slot(@secondary)}
      </div>
    </div>
    """
  end

  slot :primary
  slot :secondary

  def admin_sidebar(assigns) do
    ~H"""
    <div class="admin-sidebar">
      <div :if={@primary != []} class="admin-sidebar-section">
        {render_slot(@primary)}
      </div>
      <div :if={@secondary != []} class="admin-sidebar-section">
        {render_slot(@secondary)}
      </div>
    </div>
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true
  attr :pax, Pax.Interface.Context, default: nil
  attr :live_action, :atom, default: nil

  def admin_breadcrumbs(assigns) do
    ~H"""
    <div class="admin-breadcrumbs">
      <%= if @pax_admin.site_mod do %>
        <.pax_link class="admin-breadcrumb-link" navigate={@pax_admin.site_mod.dashboard_path()}>
          Dashboard
        </.pax_link>

        <%= if assigns[:pax] && @pax_admin.resource do %>
          <div class="admin-breadcrumb-divider">❯</div>
          <%= if @pax_admin.resource.section do %>
            <div class="admin-breadcrumb-text">
              {truncate(@pax_admin.resource.section.label, 25)}
            </div>
            <div class="admin-breadcrumb-divider">❯</div>
          <% end %>
          <.pax_link class="admin-breadcrumb-link" navigate={@pax.index_path}>
            {truncate(@pax_admin.resource.label, 25)}
          </.pax_link>
          <%= if @live_action == :new do %>
            <div class="admin-breadcrumb-divider">❯</div>
            <div class="admin-breadcrumb-edit">New</div>
          <% end %>

          <%= if @live_action == :show do %>
            <div class="admin-breadcrumb-divider">❯</div>
            <div class="admin-breadcrumb-text">
              {truncate(@pax.object_name, 25)}
            </div>
          <% end %>

          <%= if @live_action == :edit do %>
            <%= if @pax.show_path do %>
              <div class="admin-breadcrumb-divider">❯</div>
              <.pax_link class="admin-breadcrumb-link" navigate={@pax.show_path}>
                {truncate(@pax.object_name, 25)}
              </.pax_link>
            <% else %>
              <div class="admin-breadcrumb-text">
                {truncate(@pax.object_name, 25)}
              </div>
            <% end %>

            <div class="admin-breadcrumb-divider">❯</div>
            <div class="admin-breadcrumb-text">Edit</div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true

  def admin_menu(assigns) do
    ~H"""
    <div class="admin-menu">
      <.admin_menu_link
        navigate={Pax.Admin.Site.dashboard_path(@pax_admin.site_mod)}
        active={@pax_admin.active == :dashboard}
        class="admin-menu-link-dashboard"
      >
        Dashboard
      </.admin_menu_link>

      <%= for entry <- resource_tree(@pax_admin.resources) do %>
        <%= if entry.section do %>
          <.admin_menu_section pax_admin={@pax_admin} section={entry.section} resources={entry.resources} />
        <% else %>
          <%= for resource <- entry.resources do %>
            <.admin_menu_link
              navigate={Pax.Admin.Site.resource_index_path(@pax_admin.site_mod, resource.section, resource)}
              active={resource == @pax_admin.resource}
            >
              {truncate(resource.label, 35)}
            </.admin_menu_link>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :pax_admin, Pax.Admin.Context, required: true
  attr :section, Pax.Admin.Section, default: nil
  attr :resources, :list, default: []

  def admin_menu_section(assigns) do
    active = assigns.pax_admin.resource && assigns.section == assigns.pax_admin.resource.section
    assigns = Map.put(assigns, :active, active)

    ~H"""
    <div id={"admin_menu_section_#{@section.name}"} class={["admin-menu-section", @active && "expanded"]}>
      <button
        class="admin-menu-section-button"
        phx-click={JS.toggle_class("expanded", to: "#admin_menu_section_#{@section.name}")}
      >
        {truncate(@section.label, 35)}
      </button>
      <div class="admin-menu-section-indicator">
        <i class="fa-solid fa-chevron-right "></i>
      </div>
      <div class="admin-menu-section-body">
        <div class="admin-menu-section-contents">
          <%= for resource <- @resources do %>
            <.admin_menu_link
              navigate={Pax.Admin.Site.resource_index_path(@pax_admin.site_mod, resource.section, resource)}
              active={resource == @pax_admin.resource}
              indented={true}
            >
              {truncate(resource.label, 35)}
            </.admin_menu_link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :active, :boolean, default: false
  attr :indented, :boolean, default: false

  attr :rest, :global, include: ~w(
    navigate patch href replace method csrf_token
    download hreflang referrerpolicy rel target type
  )

  slot :inner_block, required: true

  def admin_menu_link(assigns) do
    ~H"""
    <.link class={["admin-menu-link", @indented && "indented", @active && "active", @class]} {@rest}>
      {render_slot(@inner_block)}
    </.link>
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
