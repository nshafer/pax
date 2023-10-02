defmodule Pax.Admin.Index.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  require Logger

  def render(site_mod, assigns) do
    %{mod: resource_mod} = assigns.resource

    cond do
      function_exported?(resource_mod, :render_index, 1) -> resource_mod.render_index(assigns)
      function_exported?(site_mod, :render_index, 1) -> site_mod.render_index(assigns)
      true -> render_index(assigns)
    end
  end

  def render_index(assigns) do
    ~H"""
    <Pax.Admin.Index.Components.index pax={@pax} resource={@resource} objects={@objects} />
    """
  end

  def pax_pre_init(site_mod, params, session, socket) do
    resource = get_resource(socket, site_mod, params, session)

    socket =
      socket
      # TODO: make this a admin_site map like dashboard
      |> assign(pax_site_mod: site_mod)
      |> assign(:page_title, resource.title)
      |> assign(:resource, resource)

    if function_exported?(resource.mod, :pax_pre_init, 3) do
      resource.mod.pax_pre_init(params, session, socket)
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

  def pax_fields(socket) do
    %{mod: resource_mod} = socket.assigns.resource

    if function_exported?(resource_mod, :pax_index_fields, 1) do
      case resource_mod.pax_index_fields(socket) do
        fields when is_list(fields) -> fields |> Pax.Field.Util.maybe_set_default_link_field()
        nil -> nil
        _ -> raise ArgumentError, "Invalid fields returned from #{inspect(resource_mod)}.pax_index_fields/3"
      end
    else
      nil
    end
  end

  def pax_singular_name(socket) do
    socket.assigns.resource.title
  end

  def pax_plural_name(socket) do
    socket.assigns.resource.title
  end

  def pax_new_path(socket) do
    site_mod = socket.assigns.pax_site_mod
    resource = socket.assigns.resource

    Pax.Admin.Site.resource_new_path(site_mod, resource.section, resource)
  end

  # TODO: remove the ability to set index_link callback, and instead just configure name of field to use in links
  # both here and in the detail view.
  def pax_field_link(site_mod, object, opts \\ []) do
    resource = Keyword.get(opts, :resource)

    cond do
      function_exported?(resource.mod, :index_link, 2) -> resource.mod.index_link(object, resource)
      function_exported?(resource.mod, :index_link, 1) -> resource.mod.index_link(object)
      function_exported?(site_mod, :index_link, 2) -> site_mod.index_link(object, resource)
      function_exported?(site_mod, :index_link, 1) -> site_mod.index_link(object)
      true -> index_link(site_mod, object, resource)
    end
  end

  defp index_link(site_mod, object, resource) do
    case resource.section do
      nil -> Pax.Admin.Site.resource_show_path(site_mod, resource.name, object)
      section -> Pax.Admin.Site.resource_show_path(site_mod, section.name, resource.name, object)
    end
  end
end
