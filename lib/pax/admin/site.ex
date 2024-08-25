defmodule Pax.Admin.Site do
  @moduledoc """
  This module is used to define the admin site for your application.

  > #### `use Pax.Admin.Site` {: .info}
  >
  > When you `use Pax.Admin.Site` this module will be imported to provide many convenience macros for defining the
  > layout of your Admin Site. It will declare `@behaviour Pax.Admin.Site` and `@before_compile Pax.Admin.Site`. It
  > will also define many attributes required by Pax.Admin for interoperability with your site. Finally it will define
  > several functions that can be used to generate paths and URLs to parts of your Admin Site.
  """

  require Logger
  alias Pax.Admin.Config
  alias Pax.Admin.Section
  alias Pax.Admin.Resource

  # TODO: add @callback render()

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

  @doc """
  This macro is used to define the admin site for your application. The `:router` option is required and should be
  the module name of your main site Router. This is required so that your Admin Site module can generate proper
  paths and urls for your Site Admin, which is used in the interface.

  ## Example

      use Pax.Admin.Site, router: MyAppWeb.Router

  """
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
      Module.put_attribute(__MODULE__, :pax_sections, %{})

      def dashboard_path(), do: Pax.Admin.Site.dashboard_path(__MODULE__)

      def resource_index_path(section \\ nil, resource),
        do: Pax.Admin.Site.resource_index_path(__MODULE__, section, resource)

      def resource_show_path(section \\ nil, resource, object_id),
        do: Pax.Admin.Site.resource_show_path(__MODULE__, section, resource, object_id)

      def resource_edit_path(section \\ nil, resource, object_id),
        do: Pax.Admin.Site.resource_edit_path(__MODULE__, section, resource, object_id)

      def resource_index_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource),
        do: Pax.Admin.Site.resource_index_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource)

      def resource_new_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource),
        do: Pax.Admin.Site.resource_new_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource)

      def resource_show_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object_id),
        do:
          Pax.Admin.Site.resource_show_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource, object_id)

      def resource_edit_url(conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object_id),
        do:
          Pax.Admin.Site.resource_edit_url(__MODULE__, conn_or_socket_or_endpoint_or_uri, section, resource, object_id)
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

  defmacro section(name, opts \\ [], do: context) when is_atom(name) and is_list(opts) do
    quote do
      Pax.Admin.Site.__section__(__MODULE__, unquote(name), unquote(opts))

      try do
        unquote(context)
      after
        Module.put_attribute(__MODULE__, :pax_current_section, nil)
      end
    end
  end

  def __section__(site_mod, name, opts) do
    case Module.get_attribute(site_mod, :pax_current_section) do
      nil ->
        put_section(site_mod, name, opts)

      _ ->
        current_section = Module.get_attribute(site_mod, :pax_current_section)
        raise "cannot embed section '#{name}' inside another section '#{current_section.name}'"
    end
  end

  defp put_section(site_mod, name, opts) do
    sections = Module.get_attribute(site_mod, :pax_sections)

    if Map.has_key?(sections, name) do
      raise "duplicate section '#{name}'"
    else
      section = %Section{
        name: name,
        path: to_string(name),
        label: Keyword.get_lazy(opts, :label, fn -> Pax.Util.Introspection.resource_name_to_label(name) end)
      }

      Module.put_attribute(site_mod, :pax_current_section, section)
      Module.put_attribute(site_mod, :pax_sections, Map.put(sections, name, section))
    end
  end

  defmacro resource(name, resource_mod, opts \\ []) when is_atom(name) and is_list(opts) do
    quote do
      Pax.Admin.Site.__resource__(__MODULE__, unquote(name), unquote(resource_mod), unquote(opts))
    end
  end

  def __resource__(site_mod, name, resource_mod, opts \\ []) do
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
        label: Keyword.get_lazy(opts, :label, fn -> Pax.Util.Introspection.resource_name_to_label(name) end),
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

  # Merge the tree of resources into a flat list, with every resource containing the section it is in.
  # This mimics how the macros work.
  defp merge_resources(resources, current_section) when is_list(resources) do
    for resource <- resources, reduce: {[], current_section} do
      {acc, current_section} -> {[parse_resource(resource, current_section) | acc], current_section}
    end
    |> elem(0)
  end

  defp merge_resources(resources, _current_section) do
    raise "invalid resources format: #{inspect(resources)}"
  end

  # This is an example of a complex return from the resources callback:
  #
  # def resources(_params, _session, _socket) do
  #   [
  #     label: %{label: "Record Labels", resource: PaxDemoWeb.MainAdmin.LabelResource},       <- C
  #     artist: %{resource: PaxDemoWeb.MainAdmin.ArtistResource, some_opt: "asdf"},    <- C
  #     library: [                                                                     <- A
  #       label: %{resource: PaxDemoWeb.MainAdmin.LabelResource},                      <- C
  #       artist: %{resource: PaxDemoWeb.MainAdmin.ArtistResource},                    <- C
  #       album: %{resource: PaxDemoWeb.MainAdmin.AlbumResource}                       <- C
  #     ],
  #     library2: %{                                                                   <- B
  #       label: "Music Library Two",
  #       resources: [
  #         album: %{resource: PaxDemoWeb.MainAdmin.AlbumResource}                     <- C
  #       ]
  #     }
  #   ]
  # end
  #
  # Comments below explain the parsing logic, with the letters pointing to specific lines they deal with marked above.

  # A. Parse this entry as section name and list of resources to go in it
  defp parse_resource({section_name, resources}, nil) when is_atom(section_name) and is_list(resources) do
    merge_resources(resources, %Section{
      name: section_name,
      path: to_string(section_name),
      label: Pax.Util.Introspection.resource_name_to_label(section_name)
    })
  end

  # If we are inside a section, then we don't allow embedding another section inside it.
  defp parse_resource({name, resources}, current_section) when is_atom(name) and is_list(resources) do
    raise "cannot embed section '#{name}' inside another section '#{current_section.name}'"
  end

  # B. Parse a section name and a map with the :resources key in it as a section with extra metadata, and the
  #    resources key pointing to a list of resources to go in it.
  defp parse_resource({section_name, %{resources: resources} = section}, nil) when is_atom(section_name) do
    merge_resources(resources, %Section{
      name: section_name,
      path: to_string(section_name),
      label: Map.get_lazy(section, :label, fn -> Pax.Util.Introspection.resource_name_to_label(section_name) end)
    })
  end

  # If we are inside a section, then we don't allow embedding another section inside it.
  defp parse_resource({name, %{resources: resources}}, current_section) when is_atom(name) and is_list(resources) do
    raise "cannot embed section '#{name}' inside another section '#{current_section.name}'"
  end

  # C. Treat an entry as a Resource if there is the :resource key in it. The current_section can be nil.
  defp parse_resource({resource_name, %{resource: resource_mod} = resource}, current_section)
       when is_atom(resource_name) do
    %Resource{
      name: resource_name,
      path: to_string(resource_name),
      label: Map.get_lazy(resource, :label, fn -> Pax.Util.Introspection.resource_name_to_label(resource_name) end),
      section: current_section,
      mod: resource_mod,
      opts: Map.drop(resource, [:label, :resource]) |> Keyword.new()
    }
  end

  # TODO: parse links, pages, etc

  # Handle invalid resources
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

  def match_resource(resources, nil, resource_name) when is_atom(resource_name) do
    Enum.find(resources, &match?(%Resource{section: nil, name: ^resource_name}, &1))
  end

  def match_resource(resources, nil, resource_path) when is_binary(resource_path) do
    Enum.find(resources, &match?(%Resource{section: nil, path: ^resource_path}, &1))
  end

  def match_resource(resources, section_name, resource_name) when is_atom(section_name) and is_atom(resource_name) do
    Enum.find(resources, &match?(%Resource{section: %{name: ^section_name}, name: ^resource_name}, &1))
  end

  def match_resource(resources, section_path, resource_path)
      when is_binary(section_path) and is_binary(resource_path) do
    Enum.find(resources, &match?(%Resource{section: %{path: ^section_path}, path: ^resource_path}, &1))
  end

  defmacro __before_compile__(env) do
    quote do
      def __pax__(:router), do: @pax_router
      def __pax__(:path), do: @pax_router.__pax__(:paths) |> Map.get(__MODULE__)
      def __pax__(:config), do: @pax_config

      @pax_resources_sorted Module.delete_attribute(__MODULE__, :pax_resources) |> Enum.reverse()
      def __pax__(:resources), do: @pax_resources_sorted

      defmodule DashboardLive do
        use Phoenix.LiveView, container: {:div, class: "admin admin-layout"}

        def render(assigns), do: Pax.Admin.Dashboard.Live.render(unquote(env.module), assigns)

        def mount(params, session, socket),
          do: Pax.Admin.Dashboard.Live.mount(unquote(env.module), params, session, socket)
      end

      defmodule ResourceLive do
        use Phoenix.LiveView, container: {:div, class: "admin admin-layout"}
        use Pax.Interface

        def render(assigns), do: Pax.Admin.Resource.Live.render(unquote(env.module), assigns)

        def pax_init(params, session, socket),
          do: Pax.Admin.Resource.Live.pax_init(unquote(env.module), params, session, socket)

        defdelegate adapter(socket), to: Pax.Admin.Resource.Live
        defdelegate plugins(socket), to: Pax.Admin.Resource.Live
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

  def dashboard_path(site_mod) do
    path = site_mod.__pax__(:path)
    "#{path}"
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
  def resource_show_path(site_mod, section \\ nil, resource, object_id) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    cond do
      section_path -> "#{path}/#{section_path}/r/#{resource_path}/#{object_id}"
      true -> "#{path}/r/#{resource_path}/#{object_id}"
    end
  end

  @doc """
  Get the path to the show page for a resource object.
  """
  def resource_edit_path(site_mod, section \\ nil, resource, object_id) do
    path = site_mod.__pax__(:path)
    section_path = section_path(section)
    resource_path = resource_path(resource)

    cond do
      section_path -> "#{path}/#{section_path}/r/#{resource_path}/#{object_id}/edit"
      true -> "#{path}/r/#{resource_path}/#{object_id}/edit"
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

  def resource_show_url(site_mod, conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object_id) do
    path = resource_show_path(site_mod, section, resource, object_id)

    case path do
      nil -> nil
      path -> Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
    end
  end

  def resource_edit_url(site_mod, conn_or_socket_or_endpoint_or_uri, section \\ nil, resource, object_id) do
    path = resource_edit_path(site_mod, section, resource, object_id)

    case path do
      nil -> nil
      path -> Phoenix.VerifiedRoutes.unverified_url(conn_or_socket_or_endpoint_or_uri, path)
    end
  end
end
