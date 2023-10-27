defmodule Pax.Admin.Resource.Live do
  use Phoenix.Component
  import Pax.Admin.Resource.Components
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
    <.index :if={@live_action == :index} pax={@pax} objects={@objects} />
    <.show :if={@live_action == :show} pax={@pax} object={@object} />
    <.new :if={@live_action == :new} pax={@pax} object={@object} form={@form} />
    <.edit :if={@live_action == :edit} pax={@pax} object={@object} form={@form} />
    """
  end

  def pax_init(site_mod, params, session, socket) do
    resources = Pax.Admin.Site.resources_for(site_mod, params, session, socket)
    resource = get_resource(resources, params)

    socket =
      socket
      |> assign(:page_title, resource.mod.plural_name(socket) || resource.label)
      |> assign_admin(site_mod: site_mod)
      |> assign_admin(config: Pax.Admin.Site.config_for(site_mod, params, session, socket))
      |> assign_admin(active: :resource)
      |> assign_admin(resources: resources)
      |> assign_admin(:resource, resource)

    resource.mod.pax_init(params, session, socket)
  end

  defp get_resource(resources, params) do
    section = Map.get(params, "section")
    resource = Map.get(params, "resource")

    case Pax.Admin.Site.match_resource(resources, section, resource) do
      nil -> raise Pax.Admin.ResourceNotFoundError.exception(section: section, resource: resource)
      %{} = resource -> resource
    end
  end

  def adapter(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    # Set the resource_mod as the callback_module for the adapter if none were specified
    case resource_mod.adapter(socket) do
      {adapter, callback_module, adapter_opts} -> {adapter, callback_module, adapter_opts}
      {adapter, adapter_opts} -> {adapter, resource_mod, adapter_opts}
      adapter when is_atom(adapter) -> {adapter, resource_mod, []}
    end
  end

  def singular_name(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.singular_name(socket) do
      name when is_binary(name) or is_nil(name) -> name
      _ -> raise ArgumentError, "Invalid name returned from #{inspect(resource_mod)}.singular_name/1"
    end
  end

  def plural_name(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.plural_name(socket) do
      name when is_binary(name) or is_nil(name) -> name
      _ -> raise ArgumentError, "Invalid name returned from #{inspect(resource_mod)}.plural_name/1"
    end
  end

  def object_name(object, socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.object_name(object, socket) do
      name when is_binary(name) or is_nil(name) -> name
      _ -> raise ArgumentError, "Invalid name returned from #{inspect(resource_mod)}.object_name/2"
    end
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
    id_field = Pax.Adapter.id_field(adapter)

    Pax.Admin.Site.resource_show_path(site_mod, resource.section, resource, object, id_field)
  end

  def edit_path(object, socket) do
    site_mod = socket.assigns.pax_admin.site_mod
    adapter = socket.assigns.pax.adapter
    resource = socket.assigns.pax_admin.resource
    id_field = Pax.Adapter.id_field(adapter)

    Pax.Admin.Site.resource_edit_path(site_mod, resource.section, resource, object, id_field)
  end

  def index_fields(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.index_fields(socket) do
      fields when is_list(fields) or is_nil(fields) -> fields
      _ -> raise ArgumentError, "Invalid fields returned from #{inspect(resource_mod)}.index_fields/1"
    end
  end

  def fieldsets(socket) do
    resource_mod = socket.assigns.pax_admin.resource.mod

    case resource_mod.fieldsets(socket) do
      fieldsets when is_list(fieldsets) or is_nil(fieldsets) -> fieldsets
      _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(resource_mod)}.fieldsets/1"
    end
  end
end
