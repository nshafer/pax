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
    <h1 class="text-2xl mb-3 flex justify-between"><%= @object_title %> <small>Pax.Admin.Detail.Live</small></h1>
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
    socket =
      socket
      |> assign(pax_admin_mod: admin_mod)
      |> assign_resource_info(admin_mod, params)

    {:cont, socket}
  end

  defp assign_resource_info(socket, admin_mod, params) do
    section = Map.get(params, "section")
    resource = Map.get(params, "resource")

    case admin_mod.__pax__(:resource, section, resource) do
      nil ->
        raise Pax.Admin.ResourceNotFoundError.exception(section: section, resource: resource)

      %{} = resource ->
        socket
        |> assign(:page_title, resource.title)
        |> assign_section_info(resource.section)
        |> assign(:pax_resource, resource.name)
        |> assign(:pax_resource_title, resource.title)
        |> assign(:pax_resource_mod, resource.mod)
        |> assign(:pax_resource_opts, resource.opts)
    end
  end

  defp assign_section_info(socket, nil) do
    socket
    |> assign(:pax_section, nil)
    |> assign(:pax_section_title, nil)
  end

  defp assign_section_info(socket, section) do
    socket
    |> assign(:pax_section, section.name)
    |> assign(:pax_section_title, section.title)
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

  def handle_params(_admin_mod, params, _uri, socket) do
    socket =
      socket
      |> assign_object_title(params)

    {:noreply, socket}
  end

  def assign_object_title(socket, params) do
    resource_mod = socket.assigns.pax_resource_mod
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

  defp detail_title(_object, params) do
    id = Map.get(params, "id")
    "Object #{id}"
  end
end
