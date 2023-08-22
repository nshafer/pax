defmodule Pax.Admin.Index.Live do
  # import Phoenix.LiveView
  use Phoenix.Component
  require Logger

  def render(admin_mod, assigns) do
    %{pax_resource_mod: resource_mod} = assigns

    cond do
      function_exported?(resource_mod, :render_index, 1) -> resource_mod.render_index(assigns)
      function_exported?(admin_mod, :render_index, 1) -> admin_mod.render_index(assigns)
      true -> render_index(assigns)
    end
  end

  def render_index(assigns) do
    ~H"""
    <h1 class="text-2xl mb-3 flex justify-between"><%= @pax_resource_title %> <small>Pax.Admin.Index.Live</small></h1>
    <Pax.Admin.Index.Components.index
      pax_section={@pax_section}
      pax_resource={@pax_resource}
      pax_resource_mod={@pax_resource_mod}
      pax_fields={@pax_fields}
      objects={@objects}
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

  def pax_fields(_admin_mod, params, session, socket) do
    resource_mod = socket.assigns.pax_resource_mod

    resource_mod.pax_index_fields(params, session, socket)
    |> maybe_set_default_link_field()
  end

  defp maybe_set_default_link_field(fields) do
    has_link? =
      Enum.any?(fields, fn
        {_name, _type} -> false
        {_name, _type, opts} -> Keyword.has_key?(opts, :link)
      end)

    if has_link? do
      fields
    else
      [first_field | rest] = fields

      first_field =
        case first_field do
          {name, type} ->
            {name, type, link: true}

          {name, type, opts} ->
            {name, type, Keyword.put(opts, :link, true)}
        end

      [first_field | rest]
    end
  end

  def link(admin_mod, object, opts \\ []) do
    resource_mod = Keyword.get(opts, :resource_mod)

    cond do
      function_exported?(resource_mod, :index_link, 2) -> resource_mod.index_link(object, opts)
      function_exported?(resource_mod, :index_link, 1) -> resource_mod.index_link(object)
      function_exported?(admin_mod, :index_link, 2) -> admin_mod.index_link(object, opts)
      function_exported?(admin_mod, :index_link, 1) -> admin_mod.index_link(object)
      true -> index_link(admin_mod, object, opts)
    end
  end

  defp index_link(admin_mod, object, opts) do
    section = Keyword.get(opts, :section)
    resource = Keyword.get(opts, :resource)

    admin_mod.resource_detail_path(section, resource, object)
  end
end
