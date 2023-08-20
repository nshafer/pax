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
    path = admin_mod.__pax__(:path)
    section = Keyword.get(opts, :section)
    resource = Keyword.get(opts, :resource)
    id = get_object_id(object)

    if id do
      case section do
        nil ->
          "#{path}/#{resource}/#{object.id}"

        section ->
          "#{path}/#{section}/#{resource}/#{object.id}"
      end
    else
      nil
    end
  end

  # Try to handle structs. Since we can find out the struct (module) then we can try a few things to introspect it:
  #
  # 1. It's a schema, so get the configured primary_key and use that to get the object's primary key value
  # 2. The struct has a function primary_key/1, so call that to get the object's primary key value
  # 3. The struct has a :primary_key field, so use that
  # 4. The struct has a function id/1, so call that to get the object's id value
  # 5. The struct has a :id field, so use that
  defp get_object_id(%{__struct__: struct} = object) do
    cond do
      function_exported?(struct, :__schema__, 1) ->
        case struct.__schema__(:primary_key) do
          [key] -> Map.get(object, key)
          [] -> raise "Compound primary keys are not supported"
        end

      function_exported?(struct, :primary_key, 1) ->
        struct.primary_key(object)

      Map.has_key?(object, :primary_key) ->
        Map.get(object, :primary_key)

      function_exported?(struct, :id, 1) ->
        struct.id(object)

      Map.has_key?(object, :id) ->
        Map.get(object, :id)

      true ->
        nil
    end
  end

  # Handle regular maps. Same as structs, but since we don't have a module to check for functions on, then just look
  # for :primary_key and :id fields.
  defp get_object_id(%{} = object) do
    cond do
      Map.has_key?(object, :primary_key) -> Map.get(object, :primary_key)
      Map.has_key?(object, :id) -> Map.get(object, :id)
      true -> nil
    end
  end

  # Everything else, just return nil, as we can't figure out how to link it
  defp get_object_id(_object), do: nil
end
