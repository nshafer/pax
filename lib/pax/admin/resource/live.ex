defmodule Pax.Admin.Resource.Live do
  use Phoenix.Component
  import Pax.Admin.Resource.Components

  def render(site_mod, assigns) do
    resource_mod = assigns.resource.mod

    cond do
      function_exported?(resource_mod, :render, 1) -> resource_mod.render_index(assigns)
      function_exported?(site_mod, :render, 1) -> site_mod.render_index(assigns)
      true -> render(assigns)
    end
  end

  def render(assigns) do
    ~H"""
    <.index :if={@live_action == :index} pax={@pax} resource={@resource} objects={@objects} />
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

  def adapter(socket) do
    resource_mod = socket.assigns.resource.mod

    # Set the resource_mod as the callback_module for the adapter if none were specified
    case resource_mod.adapter(socket) do
      {adapter, callback_module, adapter_opts} -> {adapter, callback_module, adapter_opts}
      {adapter, adapter_opts} -> {adapter, resource_mod, adapter_opts}
      adapter when is_atom(adapter) -> {adapter, resource_mod, []}
    end
  end

  def singular_name(socket) do
    socket.assigns.resource.title
  end

  def plural_name(socket) do
    # TODO: this isn't returning plural
    socket.assigns.resource.title
  end

  def object_name(object, socket) do
    resource_mod = socket.assigns.resource.mod
    adapter = socket.assigns.pax.adapter

    if function_exported?(resource_mod, :object_name, 2) do
      resource_mod.object_name(object, socket)
    else
      Pax.Adapter.object_name(adapter, object)
    end
  end

  def index_path(socket) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    Pax.Admin.Site.resource_index_path(site_mod, resource.section, resource)
  end

  def new_path(socket) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    Pax.Admin.Site.resource_new_path(site_mod, resource.section, resource)
  end

  def show_path(object, socket) do
    site_mod = socket.assigns.pax_site_mod
    adapter = socket.assigns.pax.adapter
    resource = socket.assigns.resource
    id_field = Pax.Adapter.id_field(adapter)

    Pax.Admin.Site.resource_show_path(site_mod, resource.section, resource, object, id_field)
  end

  def edit_path(object, socket) do
    site_mod = socket.assigns.pax_site_mod
    adapter = socket.assigns.pax.adapter
    resource = socket.assigns.resource
    id_field = Pax.Adapter.id_field(adapter)

    Pax.Admin.Site.resource_edit_path(site_mod, resource.section, resource, object, id_field)
  end

  def index_fields(socket) do
    resource_mod = socket.assigns.resource.mod

    if function_exported?(resource_mod, :index_fields, 1) do
      case resource_mod.index_fields(socket) do
        fields when is_list(fields) -> fields
        nil -> nil
        _ -> raise ArgumentError, "Invalid fields returned from #{inspect(resource_mod)}.index_fields/1"
      end
    else
      nil
    end
  end

  def fieldsets(socket) do
    resource_mod = socket.assigns.resource.mod

    if function_exported?(resource_mod, :fieldsets, 1) do
      case resource_mod.fieldsets(socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        nil -> nil
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(resource_mod)}.fieldsets/1"
      end
    else
      nil
    end
  end
end
