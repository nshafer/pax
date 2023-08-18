defmodule Pax.Admin do
  defmacro __using__(opts) do
    router = Keyword.get(opts, :router, nil) || raise "missing :router option"

    quote do
      import Pax.Admin
      Module.put_attribute(__MODULE__, :pax_router, unquote(router))
      Module.register_attribute(__MODULE__, :pax_config, accumulate: false)
      Module.register_attribute(__MODULE__, :pax_resources, accumulate: true)
      Module.put_attribute(__MODULE__, :pax_current_section, nil)
      @before_compile Pax.Admin
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

  defmacro section(path, name, do: context) when is_atom(path) and is_binary(name) do
    path = to_string(path)

    quote do
      # TODO: check if already in a section, raise error
      Module.put_attribute(__MODULE__, :pax_current_section, {unquote(path), unquote(name)})

      try do
        unquote(context)
      after
        Module.put_attribute(__MODULE__, :pax_current_section, nil)
      end
    end
  end

  defmacro resource(path, name, resource_mod, opts \\ []) when is_atom(path) and is_binary(name) do
    path = to_string(path)

    quote do
      Module.put_attribute(
        __MODULE__,
        :pax_resources,
        {Module.get_attribute(__MODULE__, :pax_current_section), {unquote(path), unquote(name)}, unquote(resource_mod),
         unquote(opts)}
      )
    end
  end

  defmacro __before_compile__(env) do
    quote do
      def __pax__(:router), do: @pax_router
      def __pax__(:path), do: @pax_router.__pax__(:paths) |> Map.get(__MODULE__)
      def __pax__(:config), do: @pax_config
      def __pax__(:resources), do: @pax_resources |> Enum.reverse()

      def __pax__(:resource, nil, resource) do
        __pax__(:resources)
        |> Enum.find(fn {s, r, _, _} -> s == nil and match?({^resource, _}, r) end)
        |> case do
          nil ->
            raise Pax.Admin.ResourceNotFoundError, resource: resource

          {_, {resource, resource_title}, resource_mod, resource_opts} ->
            {nil, {String.to_atom(resource), resource_title}, resource_mod, resource_opts}
        end
      end

      def __pax__(:resource, section, resource) do
        __pax__(:resources)
        |> Enum.find(fn {s, r, _, _} -> match?({^section, _}, s) and match?({^resource, _}, r) end)
        |> case do
          nil ->
            raise Pax.Admin.ResourceNotFoundError, section: section, resource: resource

          {{section, section_title}, {resource, resource_title}, resource_mod, resource_opts} ->
            {{String.to_atom(section), section_title}, {String.to_atom(resource), resource_title}, resource_mod,
             resource_opts}
        end
      end

      defmodule IndexLive do
        use Phoenix.LiveView
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
        use Phoenix.LiveView
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
end
