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
      <%= @pax_admin_mod.__pax__(:config).title %> <small>Pax.Admin.Dashboard.Live</small>
    </h1>

    <Pax.Admin.Dashboard.Components.toc pax_admin_mod={@pax_admin_mod} />
    """
  end

  def mount(admin_mod, _params, _session, socket) do
    config = admin_mod.__pax__(:config)

    socket =
      socket
      |> assign(pax_admin_mod: admin_mod)
      |> assign(pax_title: config.title)
      |> assign(pax_resource_tree: admin_mod.__pax__(:resource_tree))

    {:ok, socket}
  end
end
