defmodule Pax.Admin.Site do
  require Logger
  alias Pax.Admin.Config
  alias Pax.Admin.Section
  alias Pax.Admin.Resource

  @callback config(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: nil | map()

  @callback resources(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: nil | list()

  @optional_callbacks config: 3, resources: 3

  defmacro __using__(opts) do
    router = Keyword.get(opts, :router, nil) || raise "missing :router option"

    quote do
      import Pax.Admin.Site
      @before_compile Pax.Admin.Site
      @behaviour Pax.Admin.Site

      Module.put_attribute(__MODULE__, :pax_router, unquote(router))
      Module.put_attribute(__MODULE__, :pax_config, nil)
      Module.put_attribute(__MODULE__, :pax_current_section, nil)
      Module.register_attribute(__MODULE__, :pax_resources, accumulate: true)

      def resource_index_path(section \\ nil, resource),
        do: Pax.Admin.Site.resource_index_path(__MODULE__, section, resource)

      def resource_show_path(section \\ nil, resource, object, field \\ nil),
        do: Pax.Admin.Site.resource_show_path(__MODULE__, section, resource, object, field)

      def resource_edit_path(section \\ nil, resource, object, field \\ nil),
        do: Pax.Admin.Site.resource_edit_path(__MODULE__, section, resource, object, field)

      def resource_index_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource),
        do: Pax.Admin.Site.resource_index_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource)

      def resource_new_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource),
        do: Pax.Admin.Site.resource_new_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource)

      def resource_show_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object, field \\ nil),
        do:
          Pax.Admin.Site.resource_show_url(
            __MODULE__,
            conn_or_socket_or_endpoint_or_uri,
            section,
            resource,
            object,
            field
          )

      def resource_edit_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object, field \\ nil),
        do:
          Pax.Admin.Site.resource_edit_url(
            __MODULE__,
            conn_or_socket_or_endpoint_or_uri,
            section,
            resource,
            object,
            field
          )
    end
  end

  defmacro config(opts) do
    quote do
      Module.put_attribute(__MODULE__, :pax_config, Pax.Admin.Site.__config__(unquote(opts)))
    end
  end

  def __config__(%Config{} = config), do: config
  def __config__(nil), do: %Config{}

  def __config__(opts) when is_list(opts) do
    struct!(Config, opts)
  rescue
    error -> raise "invalid config: #{inspect(opts)}: #{Exception.message(error)}"
  end

  def __config__(conf) when is_map(conf), do: Keyword.new(conf)
  def __config__(arg), do: raise("invalid config: #{inspect(arg)}")

  def config_for(site_mod, params, session, socket) do
    if Code.ensure_loaded?(site_mod) and function_exported?(site_mod, :config, 3) do
      site_mod.config(params, session, socket)
      |> merge_config()
    else
      site_mod.__pax__(:config)
      |> merge_config()
    end
  rescue
    error -> raise "invalid config in #{site_mod}: #{Exception.message(error)}"
  end

  defp merge_config(%Config{} = conf), do: conf
  defp merge_config(nil), do: %Config{}
  defp merge_config(opts) when is_list(opts), do: struct!(Config, opts)
  defp merge_config(conf) when is_map(conf), do: Keyword.new(conf) |> merge_config()
  defp merge_config(arg), do: raise("invalid config: #{inspect(arg)}")

  # TODO: move title to opts
  defmacro section(name, title, do: context) when is_atom(name) and is_binary(title) do
    quote do
      Pax.Admin.Site.__section__(__MODULE__, unquote(name), unquote(title))

      try do
        unquote(context)
      after
        Module.put_attribute(__MODULE__, :pax_current_section, nil)
      end
    end
  end

  def __section__(site_mod, name, title) do
    case Module.get_attribute(site_mod, :pax_current_section) do
      nil ->
        Module.put_attribute(site_mod, :pax_current_section, %Section{
          name: name,
          path: to_string(name),
          title: title
        })

      _ ->
        current_section = Module.get_attribute(site_mod, :pax_current_section)
        raise "cannot embed section '#{name}' inside another section '#{current_section.name}'"
    end
  end

  # TODO: move title to opts
  defmacro resource(name, title, resource_mod, opts \\ []) when is_atom(name) and is_binary(title) do
    quote do
      Pax.Admin.Site.__resource__(__MODULE__, unquote(name), unquote(title), unquote(resource_mod), unquote(opts))
    end
  end

  def __resource__(site_mod, name, title, resource_mod, opts \\ []) do
    current_section = Module.get_attribute(site_mod, :pax_current_section)
    resources = Module.get_attribute(site_mod, :pax_resources)
    exists? = Enum.any?(resources, &match?(%{section: ^current_section, name: ^name}, &1))

    if exists? do
      if current_section do
        raise "duplicate resource '#{name}' in section '#{current_section.name}'"
      else
        raise "duplicate resource '#{name}'"
      end
    else
      Module.put_attribute(site_mod, :pax_resources, %Resource{
        name: name,
        path: to_string(name),
        title: title,
        section: current_section,
        mod: resource_mod,
        opts: opts
      })
    end
  end

  # TODO: add link, page, etc macros

  def resources_for(site_mod, params, session, socket) do
    if Code.ensure_loaded?(site_mod) and function_exported?(site_mod, :resources, 3) do
      site_mod.resources(params, session, socket)
      |> merge_resources(nil)
      |> List.flatten()
      |> Enum.reverse()
    else
      site_mod.__pax__(:resources)
    end
  end

  defp merge_resources(resources, current_section) when is_list(resources) do
    for resource <- resources, reduce: {[], current_section} do
      {acc, current_section} -> {[parse_resource(resource, current_section) | acc], current_section}
    end
    |> elem(0)
  end

  defp merge_resources(resources, _current_section) do
    raise "invalid resources format: #{inspect(resources)}"
  end

  defp parse_resource({section_name, resources}, nil) when is_atom(section_name) and is_list(resources) do
    merge_resources(resources, %Section{
      name: section_name,
      path: to_string(section_name),
      title: section_name |> to_string() |> String.capitalize()
    })
  end

  defp parse_resource({name, resources}, current_section) when is_atom(name) and is_list(resources) do
    raise "cannot embed section '#{name}' inside another section '#{current_section.name}'"
  end

  defp parse_resource({section_name, %{resources: resources} = section}, nil) when is_atom(section_name) do
    merge_resources(resources, %Section{
      name: section_name,
      path: to_string(section_name),
      title: Map.get_lazy(section, :title, fn -> section_name |> to_string() |> String.capitalize() end)
    })
  end

  defp parse_resource({name, %{resources: resources}}, current_section) when is_atom(name) and is_list(resources) do
    raise "cannot embed section '#{name}' inside another section '#{current_section.name}'"
  end

  defp parse_resource({name, %{resource: resource_mod} = resource}, current_section) when is_atom(name) do
    %Resource{
      name: name,
      path: to_string(name),
      title: Map.get_lazy(resource, :title, fn -> name |> to_string() |> String.capitalize() end),
      section: current_section,
      mod: resource_mod,
      opts: Map.drop(resource, [:title, :resource]) |> Keyword.new()
    }
  end

  # TODO: parse links, pages, etc

  defp parse_resource({name, resource}, current_section) do
    if current_section do
      raise "invalid resource #{inspect(name)}: '#{inspect(resource)}' in section '#{inspect(current_section.name)}'"
    else
      raise "duplicate resource #{inspect(name)}: '#{inspect(resource)}'"
    end
  end

  defp parse_resource(arg, current_section) do
    raise "invalid resource #{inspect(arg)} in section '#{inspect(current_section.name)}'"
  end

  def match_resource(site_mod, params, session, socket, nil, resource_name) when is_atom(resource_name) do
    resources_for(site_mod, params, session, socket)
    |> Enum.find(&match?(%Resource{section: nil, name: ^resource_name}, &1))
  end

  def match_resource(site_mod, params, session, socket, nil, resource_path) when is_binary(resource_path) do
    resources_for(site_mod, params, session, socket)
    |> Enum.find(&match?(%Resource{section: nil, path: ^resource_path}, &1))
  end

  def match_resource(site_mod, params, session, socket, section_name, resource_name)
      when is_atom(section_name) and is_atom(resource_name) do
    resources_for(site_mod, params, session, socket)
    |> Enum.find(&match?(%Resource{section: %{name: ^section_name}, name: ^resource_name}, &1))
  end

  def match_resource(site_mod, params, session, socket, section_path, resource_path)
      when is_binary(section_path) and is_binary(resource_path) do
    resources_for(site_mod, params, session, socket)
    |> Enum.find(&match?(%Resource{section: %{path: ^section_path}, path: ^resource_path}, &1))
  end

  def resource_tree(site_mod, params, session, socket) do
    resources_for(site_mod, params, session, socket)
    |> Enum.reduce({[], nil}, fn
      resource, {[], nil} ->
        {[%{section: resource.section, resources: [resource]}], resource.section}

      %{section: current_section} = resource, {[curr | rest], current_section} ->
        {[%{curr | resources: [resource | curr.resources]} | rest], current_section}

      resource, {acc, _current_section} ->
        {[%{section: resource.section, resources: [resource]} | acc], resource.section}
    end)
    |> elem(0)
    |> Enum.map(fn %{resources: resources} = entry -> %{entry | resources: Enum.reverse(resources)} end)
    |> Enum.reverse()
  end

  defmacro __before_compile__(env) do
    quote do
      def __pax__(:router), do: @pax_router
      def __pax__(:path), do: @pax_router.__pax__(:paths) |> Map.get(__MODULE__)
      def __pax__(:config), do: @pax_config

      @pax_resources_sorted Module.delete_attribute(__MODULE__, :pax_resources) |> Enum.reverse()
      def __pax__(:resources), do: @pax_resources_sorted

      defmodule DashboardLive do
        use Phoenix.LiveView, layout: {Pax.Admin.Layouts, :app}

        def render(assigns), do: Pax.Admin.Dashboard.Live.render(unquote(env.module), assigns)

        def mount(params, session, socket),
          do: Pax.Admin.Dashboard.Live.mount(unquote(env.module), params, session, socket)
      end

      defmodule ResourceLive do
        use Phoenix.LiveView, layout: {Pax.Admin.Layouts, :app}
        use Pax.Interface

        def render(assigns), do: Pax.Admin.Resource.Live.render(unquote(env.module), assigns)

        def pax_init(params, session, socket),
          do: Pax.Admin.Resource.Live.pax_init(unquote(env.module), params, session, socket)

        defdelegate adapter(socket), to: Pax.Admin.Resource.Live
        defdelegate singular_name(socket), to: Pax.Admin.Resource.Live
        defdelegate plural_name(socket), to: Pax.Admin.Resource.Live
        defdelegate object_name(object, socket), to: Pax.Admin.Resource.Live

        defdelegate index_path(socket), to: Pax.Admin.Resource.Live
        defdelegate new_path(socket), to: Pax.Admin.Resource.Live
        defdelegate show_path(object, socket), to: Pax.Admin.Resource.Live
        defdelegate edit_path(object, socket), to: Pax.Admin.Resource.Live

        defdelegate index_fields(socket), to: Pax.Admin.Resource.Live
        defdelegate fieldsets(socket), to: Pax.Admin.Resource.Live
      end
    end
  end

  defp section_path(nil), do: nil
  defp section_path(%Section{} = section), do: section.path
  defp section_path(section_path) when is_binary(section_path), do: section_path
  defp section_path(section_name) when is_atom(section_name), do: to_string(section_name)
  defp section_path(arg), do: raise("invalid section path: #{inspect(arg)}")

  defp resource_path(%Resource{} = resource), do: resource.path
  defp resource_path(resource_path) when is_binary(resource_path), do: resource_path
  defp resource_path(resource_name) when is_atom(resource_name), do: to_string(resource_name)
  defp resource_path(arg), do: raise("invalid resource path: #{inspect(arg)}")

  def resource_index_path(site_mod, section \\ nil, resource) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    cond do
      section_path -> "#{path}/#{section_path}/r/#{resource_path}"
      true -> "#{path}/r/#{resource_path}"
    end
  end

  def resource_new_path(site_mod, section \\ nil, resource) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    cond do
      section_path -> "#{path}/#{section_path}/r/#{resource_path}/new"
      true -> "#{path}/r/#{resource_path}/new"
    end
  end

  @doc """
  Get the path to the show page for a resource object.
  """
  def resource_show_path(site_mod, section \\ nil, resource, object, field \\ nil)

  def resource_show_path(site_mod, section, resource, object, nil) when is_map(object) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    case get_object_id(object) do
      nil ->
        Logger.warning("could not find unique id for object #{inspect(object)}")
        nil

      id ->
        cond do
          section_path -> "#{path}/#{section_path}/r/#{resource_path}/#{id}"
          true -> "#{path}/r/#{resource_path}/#{id}"
        end
    end
  end

  # Special case when the call gives a field but not a section
  def resource_show_path(site_mod, resource, object, field, nil) when is_map(object) do
    resource_show_path(site_mod, nil, resource, object, field)
  end

  def resource_show_path(site_mod, section, resource, object, field) when is_map(object) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    case Map.get(object, field) do
      nil ->
        Logger.warning("could not get unique id field #{inspect(field)} for object #{inspect(object)}")
        nil

      id ->
        cond do
          section_path -> "#{path}/#{section_path}/r/#{resource_path}/#{id}"
          true -> "#{path}/r/#{resource_path}/#{id}"
        end
    end
  end

  @doc """
  Get the path to the show page for a resource object.
  """
  def resource_edit_path(site_mod, section \\ nil, resource, object, field \\ nil)

  def resource_edit_path(site_mod, section, resource, object, nil) when is_map(object) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    case get_object_id(object) do
      nil ->
        Logger.warning("could not find unique id for object #{inspect(object)}")
        nil

      id ->
        cond do
          section_path -> "#{path}/#{section_path}/r/#{resource_path}/#{id}/edit"
          true -> "#{path}/r/#{resource_path}/#{id}/edit"
        end
    end
  end

  # Special case when the call gives a field but not a section
  def resource_edit_path(site_mod, resource, object, field, nil) when is_map(object) do
    resource_show_path(site_mod, nil, resource, object, field)
  end

  def resource_edit_path(site_mod, section, resource, object, field) when is_map(object) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    case Map.get(object, field) do
      nil ->
        Logger.warning("could not get unique id field #{inspect(field)} for object #{inspect(object)}")
        nil

      id ->
        cond do
          section_path -> "#{path}/#{section_path}/r/#{resource_path}/#{id}/edit"
          true -> "#{path}/r/#{resource_path}/#{id}/edit"
        end
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

  def resource_index_url(site_mod, conn_or_socket_or_endpoint_or_uri, section, resource) do
    path = resource_index_path(site_mod, section, resource)
    Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
  end

  def resource_new_url(site_mod, conn_or_socket_or_endpoint_or_uri, section, resource) do
    path = resource_new_path(site_mod, section, resource)
    Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
  end

  def resource_show_url(site_mod, conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object, field \\ nil) do
    path = resource_show_path(site_mod, section, resource, object, field)

    case path do
      nil -> nil
      path -> Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
    end
  end

  def resource_edit_url(site_mod, conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object, field \\ nil) do
    path = resource_edit_path(site_mod, section, resource, object, field)

    case path do
      nil -> nil
      path -> Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
    end
  end
end
