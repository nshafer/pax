defmodule Pax.Admin.Dashboard.Live do
  # import Phoenix.LiveView
  use Phoenix.Component

  def render(admin_mod, assigns) do
    cond do
      function_exported?(admin_mod, :render_dashboard, 1) -> admin_mod.render_dashboard(assigns)
      true -> render_dashboard(assigns)
    end
  end

  def render_dashboard(assigns) do
    ~H"""
    <h1 class="text-2xl mb-3 flex justify-between">
      <%= @dashboard.config.title %> <small>Pax.Admin.Dashboard.Live</small>
    </h1>

    <Pax.Admin.Dashboard.Components.toc dashboard={@dashboard} />
    """
  end

  def mount(admin_mod, params, session, socket) do
    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign(:dashboard, %{
        admin_mod: admin_mod,
        config: Pax.Admin.Config.config_for(admin_mod, params, session, socket),
        resource_tree: Pax.Admin.Config.resource_tree(admin_mod, params, session, socket)
      })

    {:ok, socket}
  end
end
