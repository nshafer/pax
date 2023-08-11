defmodule Pax.Detail.Live do
  use Phoenix.Component
  import Phoenix.LiveView

  @callback adapter(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {module(), keyword()}

  @callback fieldsets(
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
    end
  end

  def on_mount(module, params, session, socket) do
    IO.puts("#{__MODULE__}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    adapter = init_adapter(module, params, session, socket)
    fieldsets = init_fieldsets(module, params, session, socket)
    # plugins = init_plugins(module, params, sessions, socket)
    plugins = []

    handle_params_wrapper = fn params, uri, socket ->
      on_handle_params(module, adapter, plugins, fieldsets, params, uri, socket)
    end

    socket =
      socket
      |> assign(:adapter, adapter)
      |> assign(:plugins, plugins)
      |> assign(:fieldsets, fieldsets)
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
    if function_exported?(module, :fieldsets, 3) do
      case module.fieldsets(params, session, socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(module)}.fieldsets/3"
      end
    else
      raise """
      No fieldsets/3 callback found for #{module}.
      Please configure fieldsets by defining a fieldsets function, for example:

          def fieldsets(params, session, socket) do
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
