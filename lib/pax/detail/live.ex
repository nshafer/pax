defmodule Pax.Detail.Live do
  use Phoenix.Component
  import Phoenix.LiveView

  @callback adapter(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {module(), keyword()}

  # @callback fields(
  #             params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
  #             session :: map(),
  #             socket :: Phoenix.LiveView.Socket.t()
  #           ) :: list({atom(), atom() | module(), keyword()})

  defmacro __using__(_opts) do
    quote do
      IO.puts("Pax.Detail.Live.__using__ for #{inspect(__MODULE__)}")
      @behaviour Pax.Detail.Live

      def on_mount(:pax_detail, params, session, socket),
        do: Pax.Detail.Live.on_mount(__MODULE__, params, session, socket)

      on_mount({__MODULE__, :pax_detail})
    end
  end

  def on_mount(module, params, session, socket) do
    IO.puts("#{__MODULE__}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    adapter = init_adapter(module, params, session, socket)
    # fields = init_fields(module, params, session, socket)
    fields = []
    # plugins = init_plugins(module, params, sessions, socket)
    plugins = []

    handle_params_wrapper = fn params, uri, socket ->
      on_handle_params(module, adapter, plugins, fields, params, uri, socket)
    end

    socket =
      socket
      |> assign(:adapter, adapter)
      |> assign(:plugins, plugins)
      |> assign(:fields, fields)
      |> attach_hook(:pax_handle_params, :handle_params, handle_params_wrapper)

    {:cont, socket}
  end

  def on_handle_params(module, adapter, _plugins, _fields, params, uri, socket) do
    IO.puts("#{__MODULE__}.on_handle_params(#{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign(:object, get_object(module, adapter, params, uri, socket))

    {:cont, socket}
  end

  defp get_object(module, {adapter, adapter_opts}, params, uri, socket) do
    adapter.get_object(module, adapter_opts, params, uri, socket)
  end

  defp init_adapter(module, params, session, socket) do
    {adapter, opts} = get_adapter(module, params, session, socket)
    {adapter, adapter.init(module, opts)}
  end

  defp get_adapter(module, params, session, socket) do
    if function_exported?(module, :adapter, 3) do
      case module.adapter(params, session, socket) do
        {adapter, opts} -> {adapter, opts}
        adapter when is_atom(adapter) -> {adapter, []}
        _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.adapter/3"
      end
    else
      raise """
      No adapter/3 callback found for #{module}.
      Please configure an adapter by defining an adapter function, for example:

          def adapter(params, session, socket), do: {Pax.Detail.SchemaAdapter, schema: MyApp.MySchema}

      """
    end
  end

  # defp init_fields(module, params, session, socket) do
  #   fields = get_fields(module, params, session, socket)
  #   Enum.map(fields, &init_field(module, &1))
  # end

  # defp init_field(module, {name, type}) when is_atom(name) and is_atom(type) do
  #   init_field(module, {name, type, []})
  # end

  # defp init_field(module, {name, type, opts}) when is_atom(name) and is_atom(type) and is_list(opts) do
  #   {type, opts} = Pax.Field.init(module, type, opts)
  #   {name, type, opts}
  # end

  # defp init_field(_module, arg) do
  #   raise ArgumentError, """
  #   Invalid field #{inspect(arg)}. Must be {:name, :type, [opts]} or {:name, MyType, [opts]} where MyType
  #   implements the Pax.Field behaviour.
  #   """
  # end

  # defp get_fields(module, params, session, socket) do
  #   if function_exported?(module, :fields, 3) do
  #     case module.fields(params, session, socket) do
  #       fields when is_list(fields) -> fields
  #       _ -> raise ArgumentError, "Invalid fields returned from #{inspect(module)}.fields/3"
  #     end
  #   else
  #     raise """
  #     No fields/3 callback found for #{module}.
  #     Please configure fields by defining a fields function, for example:

  #         def fields(params, session, socket), do: [{:name, :string}, {:age, :integer}]

  #     """
  #   end
  # end
end
