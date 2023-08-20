defmodule Pax.Admin.Detail.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  require Logger

  def render(admin_mod, assigns) do
    %{pax_resource_mod: resource_mod} = assigns

    cond do
      function_exported?(resource_mod, :render_detail, 1) -> resource_mod.render_detail(assigns)
      function_exported?(admin_mod, :render_detail, 1) -> admin_mod.render_detail(assigns)
      true -> render_detail(assigns)
    end
  end

  def render_detail(assigns) do
    ~H"""
    <h1 class="text-2xl mb-3 flex justify-between"><%= @pax_resource_title %> <small>Pax.Admin.Detail.Live</small></h1>
    <Pax.Admin.Detail.Components.detail
      pax_section={@pax_section}
      pax_resource={@pax_resource}
      pax_resource_mod={@pax_resource_mod}
      pax_fieldsets={@pax_fieldsets}
      object={@object}
    />
    """
  end

  def pax_init(admin_mod, params, _session, socket) do
    section = Map.get(params, "section")
    resource = Map.get(params, "resource")

    socket =
      case admin_mod.__pax__(:resource, section, resource) do
        {nil, {resource, resource_title}, resource_mod, resource_opts} ->
          socket
          |> assign(:pax_section, nil)
          |> assign(:pax_section_title, nil)
          |> assign(:pax_resource, resource)
          |> assign(:pax_resource_title, resource_title)
          |> assign(:pax_resource_mod, resource_mod)
          |> assign(:pax_resource_opts, resource_opts)

        {{section, section_title}, {resource, resource_title}, resource_mod, resource_opts} ->
          socket
          |> assign(:pax_section, section)
          |> assign(:pax_section_title, section_title)
          |> assign(:pax_resource, resource)
          |> assign(:pax_resource_title, resource_title)
          |> assign(:pax_resource_mod, resource_mod)
          |> assign(:pax_resource_opts, resource_opts)
      end

    {:cont, socket}
  end

  def pax_adapter(_admin_mod, params, session, socket) do
    resource_mod = socket.assigns.pax_resource_mod

    # Set the resource_mod as the callback_module for the adapter if none were specified
    case resource_mod.pax_adapter(params, session, socket) do
      {adapter, callback_module, adapter_opts} -> {adapter, callback_module, adapter_opts}
      {adapter, adapter_opts} -> {adapter, resource_mod, adapter_opts}
      adapter when is_atom(adapter) -> {adapter, resource_mod, []}
    end
  end

  def pax_fieldsets(_admin_mod, params, session, socket) do
    resource_mod = socket.assigns.pax_resource_mod
    resource_mod.pax_detail_fieldsets(params, session, socket)
  end
end
