defmodule Pax.Admin.Detail.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  require Logger

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
    <h1 class="text-2xl mb-3 flex justify-between"><%= @object_title %> <small>Pax.Admin.Detail.Live</small></h1>
    <Pax.Admin.Detail.Components.detail pax={@pax} resource={@resource} object={@object} />
    """
  end

  def pax_init(site_mod, params, session, socket) do
    socket =
      socket
      # TODO: make this a admin_site map like dashboard
      |> assign(pax_site_mod: site_mod)
      |> assign_resource_info(site_mod, params, session)

    {:cont, socket}
  end

  defp assign_resource_info(socket, site_mod, params, session) do
    section = Map.get(params, "section")
    resource = Map.get(params, "resource")

    case Pax.Admin.Site.match_resource(site_mod, params, session, socket, section, resource) do
      nil ->
        raise Pax.Admin.ResourceNotFoundError.exception(section: section, resource: resource)

      %{} = resource ->
        socket
        |> assign(:page_title, resource.title)
        |> assign(:resource, resource)
    end
  end

  def pax_adapter(_site_mod, params, session, socket) do
    %{mod: resource_mod} = socket.assigns.resource

    # Set the resource_mod as the callback_module for the adapter if none were specified
    case resource_mod.pax_adapter(params, session, socket) do
      {adapter, callback_module, adapter_opts} -> {adapter, callback_module, adapter_opts}
      {adapter, adapter_opts} -> {adapter, resource_mod, adapter_opts}
      adapter when is_atom(adapter) -> {adapter, resource_mod, []}
    end
  end

  def pax_fieldsets(_site_mod, params, session, socket) do
    %{mod: resource_mod} = socket.assigns.resource

    if function_exported?(resource_mod, :pax_detail_fieldsets, 3) do
      case resource_mod.pax_detail_fieldsets(params, session, socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        nil -> nil
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(resource_mod)}.pax_detail_fieldsets/3"
      end
    else
      nil
    end
  end

  def handle_params(_site_mod, params, _uri, socket) do
    socket =
      socket
      |> assign_object_title(params)

    {:noreply, socket}
  end

  def assign_object_title(socket, params) do
    %{mod: resource_mod} = socket.assigns.resource
    object_title = get_object_title(resource_mod, socket.assigns.object, params)

    socket
    |> assign(page_title: object_title)
    |> assign(object_title: object_title)
  end

  def get_object_title(resource_mod, object, params) do
    cond do
      function_exported?(resource_mod, :detail_title, 1) -> resource_mod.detail_title(object)
      true -> detail_title(object, params)
    end
  end

  # Treat object as a struct
  defp detail_title(%{__struct__: struct_mod}, params) do
    struct_name =
      struct_mod
      |> Module.split()
      |> List.last()
      |> String.replace("_", " ")
      |> String.capitalize()

    id = Map.get(params, "id")

    "#{struct_name} #{id}"
  end

  # Everything else, just call it an Object
  defp detail_title(_object, params) do
    id = Map.get(params, "id")
    "Object #{id}"
  end
end
