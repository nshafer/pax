defmodule Pax.Detail.Live do
  use Phoenix.Component
  import Phoenix.LiveView
  @type field() :: Pax.Field.field()

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
            ) :: list(field()) | list(list(field) | field()) | keyword(list(field))

  defmacro __using__(_opts) do
    quote do
      IO.puts("Pax.Detail.Live.__using__ for #{inspect(__MODULE__)}")
      @behaviour Pax.Detail.Live

      def on_mount(:pax_detail, params, session, socket),
        do: Pax.Detail.Live.on_mount(__MODULE__, params, session, socket)

      on_mount({__MODULE__, :pax_detail})

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def pax_adapter(_params, _session, _socket) do
        raise """
        No pax_adapter/3 callback found for #{__MODULE__}.
        Please configure an adapter by defining a pax_adapter function, for example:

            def pax_adapter(_params, _session, _socket),
              do: {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}

        """
      end

      def pax_fieldsets(_params, _session, _socket) do
        raise """
        No pax_fieldsets/3 callback found for #{__MODULE__}.
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

      defoverridable pax_init: 3, pax_adapter: 3, pax_fieldsets: 3
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

  def on_handle_params(_module, adapter, _plugins, _fieldsets, params, uri, socket) do
    # IO.puts("#{__MODULE__}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign(:object, Pax.Adapter.get_object(adapter, params, uri, socket))

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

  defp init_fieldsets(module, params, session, socket) do
    fieldsets =
      case module.pax_fieldsets(params, session, socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(module)}.fieldsets/3"
      end

    # Check if the user just returned a keyword list of fieldset name -> fields, and if not, make it :default
    if is_fieldsets?(fieldsets) do
      Enum.map(fieldsets, &init_fieldset(module, &1))
    else
      [init_fieldset(module, {:default, fieldsets})]
    end
    |> dbg()
  end

  defp is_fieldsets?(fieldsets) do
    Enum.all?(fieldsets, fn
      {name, value} when is_atom(name) and is_list(value) -> true
      _ -> false
    end)
  end

  defp init_fieldset(module, {name, fields}) when is_atom(name) and is_list(fields) do
    dbg()
    {name, Enum.map(fields, &init_fieldgroup(module, &1))}
  end

  # A fieldgroup can be a list of fields to display on one line, or just one field to display by itself
  defp init_fieldgroup(module, groups) when is_list(groups) do
    dbg()
    Enum.map(groups, &Pax.Field.init(module, &1))
  end

  defp init_fieldgroup(module, field) do
    dbg()
    [Pax.Field.init(module, field)]
  end
end
