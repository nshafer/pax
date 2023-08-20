defmodule Pax.Index.Live do
  use Phoenix.Component
  import Phoenix.LiveView

  @callback pax_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback pax_adapter(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback pax_fields(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: list({atom(), atom() | module(), keyword()})

  @callback link(object :: map()) :: String.t()

  @optional_callbacks [link: 1]

  defmacro __using__(_opts) do
    quote do
      # IO.puts("Pax.Index.Live.__using__ for #{inspect(__MODULE__)}")
      @behaviour Pax.Index.Live

      def on_mount(:pax_index, params, session, socket),
        do: Pax.Index.Live.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_index}

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def pax_adapter(_params, _session, _socket) do
        raise """
        No pax_adapter/3 callback found for #{__MODULE__}.
        Please configure an adapter by defining a pax_adapter function, for example:

            def pax_adapter(_params, _session, _socket),
              do: {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}

        """
      end

      defoverridable pax_init: 3, pax_adapter: 3
    end
  end

  def on_mount(module, params, session, socket) do
    # IO.puts("#{__MODULE__}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    case module.pax_init(params, session, socket) do
      {:cont, socket} -> init(module, params, session, socket)
      {:halt, socket} -> {:halt, socket}
    end
  end

  def init(module, params, session, socket) do
    # IO.puts("#{__MODULE__}.init(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    adapter = init_adapter(module, params, session, socket)
    # plugins = init_plugins(module, params, sessions, socket)
    plugins = []
    fields = init_fields(module, params, session, socket)

    handle_params_wrapper = fn params, uri, socket ->
      on_handle_params(module, adapter, plugins, fields, params, uri, socket)
    end

    socket =
      socket
      |> assign(:pax_adapter, adapter)
      |> assign(:pax_plugins, plugins)
      |> assign(:pax_fields, fields)
      |> attach_hook(:pax_handle_params, :handle_params, handle_params_wrapper)

    {:cont, socket}
  end

  def on_handle_params(_module, adapter, _plugins, _fields, params, uri, socket) do
    # IO.puts("#{__MODULE__}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign(:objects, Pax.Adapter.list_objects(adapter, params, uri, socket))

    {:cont, socket}
  end

  defp init_adapter(module, params, session, socket) do
    case module.pax_adapter(params, session, socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/3"
    end
  end

  defp init_fields(module, params, session, socket) do
    fields = get_fields(module, params, session, socket)
    Enum.map(fields, &init_field(module, &1))
  end

  defp init_field(module, {name, type}) when is_atom(name) and is_atom(type) do
    init_field(module, {name, type, []})
  end

  defp init_field(module, {name, type, opts}) when is_atom(name) and is_atom(type) and is_list(opts) do
    {type, opts} = Pax.Field.init(module, type, opts)
    {name, type, opts}
  end

  defp init_field(_module, arg) do
    raise ArgumentError, """
    Invalid field #{inspect(arg)}. Must be {:name, :type, [opts]} or {:name, MyType, [opts]} where MyType
    implements the Pax.Field behaviour.
    """
  end

  defp get_fields(module, params, session, socket) do
    if function_exported?(module, :pax_fields, 3) do
      case module.pax_fields(params, session, socket) do
        fields when is_list(fields) -> fields
        _ -> raise ArgumentError, "Invalid fields returned from #{inspect(module)}.pax_fields/3"
      end
    else
      raise """
      No pax_fields/3 callback found for #{module}.
      Please configure fields by defining a pax_fields function, for example:

          def pax_fields(params, session, socket), do: [{:name, :string}, {:age, :integer}]

      """
    end
  end
end
