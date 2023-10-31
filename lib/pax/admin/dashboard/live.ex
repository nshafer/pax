defmodule Pax.Admin.Dashboard.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  import Pax.Admin.Context
  import Pax.Components

  def render(site_mod, assigns) do
    cond do
      function_exported?(site_mod, :render_dashboard, 1) -> site_mod.render_dashboard(assigns)
      true -> render_dashboard(assigns)
    end
  end

  def render_dashboard(assigns) do
    ~H"""
    <.pax_header>
      <:primary>
        <.pax_title>
          Dashboard
        </.pax_title>
      </:primary>
    </.pax_header>
    """
  end

  def mount(site_mod, params, session, socket) do
    resources = Pax.Admin.Site.resources_for(site_mod, params, session, socket)

    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign_admin(site_mod: site_mod)
      |> assign_admin(config: Pax.Admin.Site.config_for(site_mod, params, session, socket))
      |> assign_admin(active: :dashboard)
      |> assign_admin(resources: resources)

    {:ok, socket}
  end
end
