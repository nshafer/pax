defmodule Pax.Admin.Dashboard.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  import Pax.Admin, only: [assign_admin: 2, assign_admin: 3], warn: false
  import Pax.Components

  def render(admin_mod, assigns) do
    cond do
      function_exported?(admin_mod, :render_dashboard, 1) -> admin_mod.render_dashboard(assigns)
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

  def mount(admin_mod, params, session, socket) do
    resources = Pax.Admin.resources_for(admin_mod, params, session, socket)

    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign_admin(admin_mod: admin_mod)
      |> assign_admin(config: Pax.Admin.config_for(admin_mod, params, session, socket))
      |> assign_admin(active: :dashboard)
      |> assign_admin(resources: resources)

    {:ok, socket}
  end
end
