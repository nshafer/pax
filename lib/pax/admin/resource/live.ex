defmodule Pax.Admin.Resource.Live do
  use Phoenix.Component
  import Pax.Interface.Components
  import Pax.Admin.Context

  def render(site_mod, assigns) do
    resource_mod = assigns.pax_admin.resource.mod

    cond do
      function_exported?(resource_mod, :render, 1) -> resource_mod.render_index(assigns)
      function_exported?(site_mod, :render, 1) -> site_mod.render_index(assigns)
      true -> render(assigns)
    end
  end

  def render(assigns) do
    ~H"""
    <.pax_index :if={@live_action == :index} pax={@pax} />
    <.pax_show :if={@live_action == :show} pax={@pax} />
    <.pax_new :if={@live_action == :new} pax={@pax} />
    <.pax_edit :if={@live_action == :edit} pax={@pax} />
    """
  end

  def pax_init(site_mod, params, session, socket) do
    resources = Pax.Admin.Site.resources_for(site_mod, params, session, socket)
    resource = get_resource(resources, params)

    socket =
      socket
      |> assign_admin(site_mod: site_mod)
      |> assign_admin(config: Pax.Admin.Site.config_for(site_mod, params, session, socket))
      |> assign_admin(active: :resource)
      |> assign_admin(resources: resources)
      |> assign_admin(resource: resource)

    resource.mod.init(params, session, socket)
  end

  def handle_params(_params, _uri, socket) do
    config = socket.assigns.pax.config
    resource = socket.assigns.pax_admin.resource

    socket =
      socket
      |> assign(page_title: Pax.Config.get(config, :plural_name, [socket], resource.label))

    {:noreply, socket}
  end

  defp get_resource(resources, params) do
    section = Map.get(params, "section")
    resource = Map.get(params, "resource")

    case Pax.Admin.Site.match_resource(resources, section, resource) do
      nil -> raise Pax.Admin.ResourceNotFoundError.exception(section: section, resource: resource)
      %{} = resource -> resource
    end
  end

  def pax_adapter(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    # Set the resource_mod as the callback_module for the adapter if none were specified
    case resource_mod.adapter(socket) do
      {adapter, callback_module, adapter_opts} -> {adapter, callback_module, adapter_opts}
      {adapter, adapter_opts} -> {adapter, resource_mod, adapter_opts}
      adapter when is_atom(adapter) -> {adapter, resource_mod, []}
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(resource_mod)}.adapter/1"
    end
  end

  def pax_plugins(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.plugins(socket) do
      plugins when is_list(plugins) or is_nil(plugins) -> plugins
      _ -> raise ArgumentError, "Invalid plugins returned from #{inspect(resource_mod)}.plugins/1"
    end
  end

  def pax_config(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.config(socket) do
      config_data when is_map(config_data) -> merge_config(config_data)
      config_data when is_list(config_data) -> merge_config(Map.new(config_data))
      _ -> raise ArgumentError, "Invalid config returned from #{inspect(resource_mod)}.config/1"
    end
  end

  defp merge_config(config_data) when is_map(config_data) do
    default_config_data = %{
      index_path: &index_path/1,
      new_path: &new_path/1,
      show_path: &show_path/2,
      edit_path: &edit_path/2
    }

    Map.merge(default_config_data, config_data)
  end

  def index_path(socket) do
    site_mod = socket.assigns.pax_admin.site_mod
    resource = socket.assigns.pax_admin.resource

    Pax.Admin.Site.resource_index_path(site_mod, resource.section, resource)
  end

  def new_path(socket) do
    site_mod = socket.assigns.pax_admin.site_mod
    resource = socket.assigns.pax_admin.resource

    Pax.Admin.Site.resource_new_path(site_mod, resource.section, resource)
  end

  def show_path(object, socket) do
    site_mod = socket.assigns.pax_admin.site_mod
    adapter = socket.assigns.pax.adapter
    resource = socket.assigns.pax_admin.resource
    object_id = Pax.Adapter.object_id(adapter, object)

    Pax.Admin.Site.resource_show_path(site_mod, resource.section, resource, object_id)
  end

  def edit_path(object, socket) do
    site_mod = socket.assigns.pax_admin.site_mod
    adapter = socket.assigns.pax.adapter
    resource = socket.assigns.pax_admin.resource
    object_id = Pax.Adapter.object_id(adapter, object)

    Pax.Admin.Site.resource_edit_path(site_mod, resource.section, resource, object_id)
  end
end
