defmodule Pax.Admin.Dashboard.Live do
  # import Phoenix.LiveView
  use Phoenix.Component

  def render(site_mod, assigns) do
    cond do
      function_exported?(site_mod, :render_dashboard, 1) -> site_mod.render_dashboard(assigns)
      true -> render_dashboard(assigns)
    end
  end

  def render_dashboard(assigns) do
    ~H"""
    <h1 class="text-2xl mb-3 flex justify-between">
      <%= @admin_site.config.title %> <small>Pax.Admin.Dashboard.Live</small>
    </h1>

    <Pax.Admin.Dashboard.Components.toc admin_site={@admin_site} />
    """
  end

  def mount(site_mod, params, session, socket) do
    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign(:admin_site, %{
        mod: site_mod,
        config: Pax.Admin.Site.config_for(site_mod, params, session, socket),
        resource_tree: Pax.Admin.Site.resource_tree(site_mod, params, session, socket)
      })

    {:ok, socket}
  end
end
