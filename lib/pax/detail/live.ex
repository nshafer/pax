defmodule Pax.Detail.Live do
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

  @callback pax_fieldsets(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: keyword(list({atom(), atom() | module(), keyword()}))

  defmacro __using__(_opts) do
    quote do
      IO.puts("Pax.Detail.Live.__using__ for #{inspect(__MODULE__)}")
      @behaviour Pax.Detail.Live

      def on_mount(:pax_detail, params, session, socket),
        do: Pax.Detail.Live.on_mount(__MODULE__, params, session, socket)

      on_mount({__MODULE__, :pax_detail})

      def pax_init(_params, _session, socket), do: {:cont, socket}

      defoverridable pax_init: 3
    end
  end

  def on_mount(module, params, session, socket) do
    IO.puts("#{__MODULE__}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    case module.pax_init(params, session, socket) do
      {:cont, socket} -> init(module, params, session, socket)
      {:halt, socket} -> {:halt, socket}
    end
  end

  def init(module, params, session, socket) do
    adapter = init_adapter(module, params, session, socket)
    fieldsets = init_fieldsets(module, params, session, socket)
    # plugins = init_plugins(module, params, sessions, socket)
    plugins = []

    handle_params_wrapper = fn params, uri, socket ->
      on_handle_params(module, adapter, plugins, fieldsets, params, uri, socket)
    end

    socket =
      socket
      |> assign(:pax_adapter, adapter)
      |> assign(:pax_plugins, plugins)
      |> assign(:pax_fieldsets, fieldsets)
      |> attach_hook(:pax_handle_params, :handle_params, handle_params_wrapper)

    {:cont, socket}
  end

  def on_handle_params(module, adapter, _plugins, _fieldsets, params, uri, socket) do
    IO.puts("#{__MODULE__}.on_handle_params(#{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign(:object, get_object(module, adapter, params, uri, socket))

    {:cont, socket}
  end

  defp get_object(_module, {adapter, callback_module, adapter_opts}, params, uri, socket) do
    adapter.get_object(callback_module, adapter_opts, params, uri, socket)
  end

  defp init_adapter(module, params, session, socket) do
    {adapter, callback_module, opts} = get_adapter(module, params, session, socket)
    {adapter, callback_module, adapter.init(callback_module, opts)}
  end

  defp get_adapter(module, params, session, socket) do
    if function_exported?(module, :pax_adapter, 3) do
      case module.pax_adapter(params, session, socket) do
        {adapter, callback_module, opts} -> {adapter, callback_module, opts}
        {adapter, opts} -> {adapter, module, opts}
        adapter when is_atom(adapter) -> {adapter, module, []}
        _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/3"
      end
    else
      raise """
      No pax_adapter/3 callback found for #{module}.
      Please configure an adapter by defining a pax_adapter function, for example:

          def pax_adapter(params, session, socket), do: {Pax.Detail.SchemaAdapter, schema: MyApp.MySchema}

      """
    end
  end

  defp init_fieldsets(module, params, session, socket) do
    fieldsets = get_fieldsets(module, params, session, socket)

    if is_fieldsets(fieldsets) do
      Enum.map(fieldsets, &init_fieldset(module, &1))
    else
      [default: Enum.map(fieldsets, &init_field(module, &1))]
    end
  end

  defp is_fieldsets(fieldsets) do
    Enum.all?(fieldsets, fn
      {name, value} when is_atom(name) and is_list(value) -> true
      _ -> false
    end)
  end

  defp init_fieldset(module, {name, fields}) when is_atom(name) and is_list(fields) do
    {name, Enum.map(fields, &init_field(module, &1))}
  end

  defp init_field(module, {name, type}) when is_atom(name) and is_atom(type) do
    init_field(module, {name, type, []})
  end

  defp init_field(module, {name, type, opts}) when is_atom(name) and is_atom(type) and is_list(opts) do
    {type, opts} = Pax.Field.init(module, type, opts)
    [{name, type, opts}]
  end

  defp init_field(module, fields) when is_list(fields) do
    Enum.flat_map(fields, &init_field(module, &1))
  end

  defp init_field(_module, arg) do
    raise ArgumentError, """
    Invalid field #{inspect(arg)}. Must be {:name, :type, [opts]} or {:name, MyType, [opts]} where MyType
    implements the Pax.Field behaviour.
    """
  end

  defp get_fieldsets(module, params, session, socket) do
    if function_exported?(module, :pax_fieldsets, 3) do
      case module.pax_fieldsets(params, session, socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(module)}.fieldsets/3"
      end
    else
      raise """
      No pax_fieldsets/3 callback found for #{module}.
      Please configure fieldsets by defining a pax_fieldsets function, for example:

          def pax_fieldsets(params, session, socket) do
            [
              default: [
                [{:id, :integer}, {:uuid: :string}],
                {:name, :string},
                {:age, :float, round: 1}
              ],
              metadata: [
                {:created_at, :datetime},
                {:updated_at, :datetime}
              ]
            ]
          end

      """
    end
  end
end
