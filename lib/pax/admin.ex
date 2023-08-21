defmodule Pax.Admin do
  require Logger

  defmacro __using__(opts) do
    router = Keyword.get(opts, :router, nil) || raise "missing :router option"

    quote do
      import Pax.Admin
      Module.put_attribute(__MODULE__, :pax_router, unquote(router))
      Module.register_attribute(__MODULE__, :pax_config, accumulate: false)
      Module.register_attribute(__MODULE__, :pax_resources, accumulate: true)
      Module.put_attribute(__MODULE__, :pax_current_section, nil)
      @before_compile Pax.Admin

      def resource_index_path(section \\ nil, resource),
        do: Pax.Admin.resource_index_path(__MODULE__, section, resource)

      def resource_detail_path(section \\ nil, resource, object, field \\ nil),
        do: Pax.Admin.resource_detail_path(__MODULE__, section, resource, object, field)

      def resource_index_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource),
        do: Pax.Admin.resource_index_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource)

      def resource_detail_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object, field \\ nil),
        do:
          Pax.Admin.resource_detail_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource, object, field)
    end
  end

  defmacro config(opts) do
    quote do
      Module.put_attribute(__MODULE__, :pax_config, Pax.Admin.__config__(unquote(opts)))
    end
  end

  def __config__(opts) do
    defaults = %{
      title: "Pax Admin"
    }

    Map.merge(defaults, Map.new(opts))
  end

  defmacro section(name, title, do: context) when is_atom(name) and is_binary(title) do
    quote do
      Pax.Admin.__section__(__MODULE__, unquote(name), unquote(title))

      try do
        unquote(context)
      after
        Module.put_attribute(__MODULE__, :pax_current_section, nil)
      end
    end
  end

  def __section__(admin_mod, name, title) do
    case Module.get_attribute(admin_mod, :pax_current_section) do
      nil ->
        Module.put_attribute(admin_mod, :pax_current_section, %{
          name: name,
          path: to_string(name),
          title: title
        })

      _ ->
        raise "cannot embed section inside another section"
    end
  end

  defmacro resource(name, title, resource_mod, opts \\ []) when is_atom(name) and is_binary(title) do
    quote do
      Pax.Admin.__resource__(__MODULE__, unquote(name), unquote(title), unquote(resource_mod), unquote(opts))
    end
  end

  def __resource__(admin_mod, name, title, resource_mod, opts \\ []) do
    current_section = Module.get_attribute(admin_mod, :pax_current_section)
    resources = Module.get_attribute(admin_mod, :pax_resources)
    exists? = Enum.any?(resources, &match?(%{section: ^current_section, name: ^name}, &1))

    if exists? do
      if current_section do
        raise "duplicate resource #{inspect(name)} in section #{inspect(current_section.name)}"
      else
        raise "duplicate resource #{inspect(name)}"
      end
    else
      Module.put_attribute(admin_mod, :pax_resources, %{
        section: current_section,
        name: name,
        path: to_string(name),
        title: title,
        mod: resource_mod,
        opts: opts
      })
    end
  end

  defmacro __before_compile__(env) do
    quote do
      def __pax__(:router), do: @pax_router
      def __pax__(:path), do: @pax_router.__pax__(:paths) |> Map.get(__MODULE__)
      def __pax__(:config), do: @pax_config
      def __pax__(:resources), do: @pax_resources |> Enum.reverse()

      def __pax__(:resource, nil, resource_name) when is_atom(resource_name) do
        __pax__(:resources) |> Enum.find(&match?(%{section: nil, name: ^resource_name}, &1))
      end

      def __pax__(:resource, nil, resource_path) when is_binary(resource_path) do
        __pax__(:resources) |> Enum.find(&match?(%{section: nil, path: ^resource_path}, &1))
      end

      def __pax__(:resource, section_name, resource_name) when is_atom(section_name) and is_atom(resource_name) do
        __pax__(:resources) |> Enum.find(&match?(%{section: %{name: ^section_name}, name: ^resource_name}, &1))
      end

      def __pax__(:resource, section_path, resource_path) when is_binary(section_path) and is_binary(resource_path) do
        __pax__(:resources) |> Enum.find(&match?(%{section: %{path: ^section_path}, path: ^resource_path}, &1))
      end

      def __pax__(:resource_tree) do
        __pax__(:resources)
        |> Enum.reduce({nil, []}, fn
          resource, {nil, []} ->
            {resource.section, [%{section: resource.section, resources: [resource]}]}

          %{section: current_section} = resource, {current_section, [curr | rest]} ->
            {current_section, [%{curr | resources: [resource | curr.resources]} | rest]}

          resource, {_current_section, acc} ->
            {resource.section, [%{section: resource.section, resources: [resource]} | acc]}
        end)
        |> elem(1)
        |> Enum.map(fn %{resources: resources} = entry -> %{entry | resources: Enum.reverse(resources)} end)
        |> Enum.reverse()
      end

      defmodule DashboardLive do
        use Phoenix.LiveView, layout: {Pax.Admin.Layouts, :app}

        def render(assigns), do: Pax.Admin.Dashboard.Live.render(unquote(env.module), assigns)

        def mount(params, session, socket),
          do: Pax.Admin.Dashboard.Live.mount(unquote(env.module), params, session, socket)
      end

      defmodule IndexLive do
        use Phoenix.LiveView, layout: {Pax.Admin.Layouts, :app}
        use Pax.Index.Live

        def render(assigns), do: Pax.Admin.Index.Live.render(unquote(env.module), assigns)

        def pax_init(params, session, socket),
          do: Pax.Admin.Index.Live.pax_init(unquote(env.module), params, session, socket)

        def pax_adapter(params, session, socket),
          do: Pax.Admin.Index.Live.pax_adapter(unquote(env.module), params, session, socket)

        def pax_fields(params, session, socket),
          do: Pax.Admin.Index.Live.pax_fields(unquote(env.module), params, session, socket)

        def link(object, opts \\ []), do: Pax.Admin.Index.Live.link(unquote(env.module), object, opts)
      end

      defmodule DetailLive do
        use Phoenix.LiveView, layout: {Pax.Admin.Layouts, :app}
        use Pax.Detail.Live

        def render(assigns), do: Pax.Admin.Detail.Live.render(unquote(env.module), assigns)

        def pax_init(params, session, socket),
          do: Pax.Admin.Detail.Live.pax_init(unquote(env.module), params, session, socket)

        def pax_adapter(params, session, socket),
          do: Pax.Admin.Detail.Live.pax_adapter(unquote(env.module), params, session, socket)

        def pax_fieldsets(params, session, socket),
          do: Pax.Admin.Detail.Live.pax_fieldsets(unquote(env.module), params, session, socket)
      end
    end
  end

  def resource_index_path(admin_mod, section \\ nil, resource) do
    path = admin_mod.__pax__(:path)

    cond do
      section ->
        "#{path}/#{section}/#{resource}"

      true ->
        "#{path}/_/#{resource}"
    end
  end

  @doc """
  Get the path to the detail page for a resource object.
  """
  def resource_detail_path(admin_mod, section \\ nil, resource, object, field \\ nil)

  def resource_detail_path(admin_mod, nil, resource, object, nil)
      when is_atom(admin_mod) and is_atom(resource) and is_map(object) do
    resource_detail_path(admin_mod, :_, resource, object, nil)
  end

  def resource_detail_path(admin_mod, section, resource, object, nil)
      when is_atom(admin_mod) and is_atom(section) and is_atom(resource) and is_map(object) do
    path = admin_mod.__pax__(:path)

    case get_object_id(object) do
      nil ->
        Logger.warning("could not find unique id for object #{inspect(object)}")
        nil

      id ->
        "#{path}/#{section}/#{resource}/#{id}"
    end
  end

  # Special case when the call gives a field but not a section
  def resource_detail_path(admin_mod, resource, object, field, nil)
      when is_atom(admin_mod) and is_atom(resource) and is_map(object) and is_atom(field) do
    resource_detail_path(admin_mod, :_, resource, object, field)
  end

  def resource_detail_path(admin_mod, section, resource, object, field)
      when is_atom(admin_mod) and is_atom(section) and is_atom(resource) and is_map(object) and is_atom(field) do
    path = admin_mod.__pax__(:path)

    case Map.get(object, field) do
      nil ->
        Logger.warning("could not get unique id field #{inspect(field)} for object #{inspect(object)}")
        nil

      id ->
        "#{path}/#{section}/#{resource}/#{id}"
    end
  end

  # Try to handle structs. Since we can find out the struct's module, then we can try a few things to introspect it to
  # see if:
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

  def resource_index_url(admin_mod, conn_or_socket_or_endpoint_or_uri, section, resource) do
    path = resource_index_path(admin_mod, section, resource)
    Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
  end

  def resource_detail_url(admin_mod, conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object, field \\ nil) do
    path = resource_detail_path(admin_mod, section, resource, object, field)

    case path do
      nil -> nil
      path -> Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
    end
  end
end
