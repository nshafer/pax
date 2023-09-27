defmodule Pax.Admin.Detail.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  require Logger
  import Pax.Admin.Detail.Components

  def render(site_mod, assigns) do
    %{mod: resource_mod} = assigns.resource

    cond do
      function_exported?(resource_mod, :render_detail, 1) -> resource_mod.render_detail(assigns)
      function_exported?(site_mod, :render_detail, 1) -> site_mod.render_detail(assigns)
      true -> render_detail(assigns)
    end
  end

  def render_detail(assigns) do
    ~H"""
    <.show :if={@live_action == :show} pax={@pax} object={@object} />
    <.edit :if={@live_action in [:edit, :new]} pax={@pax} object={@object} form={@form} />
    """
  end

  def pax_init(site_mod, params, session, socket) do
    resource = get_resource(socket, site_mod, params, session)

    socket =
      socket
      # TODO: make this a admin_site map like dashboard
      |> assign(pax_site_mod: site_mod)
      |> assign(:page_title, resource.title)
      |> assign(:resource, resource)

    if function_exported?(resource.mod, :pax_init, 3) do
      resource.mod.pax_init(params, session, socket)
    else
      {:cont, socket}
    end
  end

  defp get_resource(socket, site_mod, params, session) do
    section = Map.get(params, "section")
    resource = Map.get(params, "resource")

    case Pax.Admin.Site.match_resource(site_mod, params, session, socket, section, resource) do
      nil -> raise Pax.Admin.ResourceNotFoundError.exception(section: section, resource: resource)
      %{} = resource -> resource
    end
  end

  def pax_adapter(socket) do
    %{mod: resource_mod} = socket.assigns.resource

    # Set the resource_mod as the callback_module for the adapter if none were specified
    case resource_mod.pax_adapter(socket) do
      {adapter, callback_module, adapter_opts} -> {adapter, callback_module, adapter_opts}
      {adapter, adapter_opts} -> {adapter, resource_mod, adapter_opts}
      adapter when is_atom(adapter) -> {adapter, resource_mod, []}
    end
  end

  def pax_fieldsets(socket) do
    %{mod: resource_mod} = socket.assigns.resource

    if function_exported?(resource_mod, :pax_detail_fieldsets, 1) do
      case resource_mod.pax_detail_fieldsets(socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        nil -> nil
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(resource_mod)}.pax_detail_fieldsets/3"
      end
    else
      nil
    end
  end

  def pax_object_name(socket, object) do
    %{mod: resource_mod} = socket.assigns.resource
    %{adapter: adapter} = socket.assigns.pax

    if function_exported?(resource_mod, :object_name, 2) do
      resource_mod.object_name(socket, object)
    else
      Pax.Adapter.object_name(adapter, object)
    end
  end

  def pax_index_path(socket) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    Pax.Admin.Site.resource_index_path(site_mod, resource.section, resource)
  end

  def pax_new_path(socket) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    Pax.Admin.Site.resource_new_path(site_mod, resource.section, resource)
  end

  def pax_show_path(socket, object) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    Pax.Admin.Site.resource_show_path(site_mod, resource.section, resource, object)
  end

  def pax_edit_path(socket, object) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    # TODO: make this work with custom fields? like :uuid
    Pax.Admin.Site.resource_edit_path(site_mod, resource.section, resource, object)
  end
end
