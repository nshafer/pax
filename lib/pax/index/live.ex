defmodule Pax.Index.Live do
  use Phoenix.Component
  import Phoenix.LiveView
  import Pax.Util.Live

  @type fields() :: list(Pax.Field.fieldspec())

  @callback pax_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback pax_adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback pax_fields(socket :: Phoenix.LiveView.Socket.t()) :: fields() | nil
  @callback pax_singular_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_plural_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_new_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()

  @optional_callbacks pax_singular_name: 1, pax_plural_name: 1, pax_new_path: 1

  defmacro __using__(_opts) do
    quote do
      # IO.puts("Pax.Index.Live.__using__ for #{inspect(__MODULE__)}")
      @behaviour Pax.Index.Live
      @behaviour Pax.Field.Callback

      def on_mount(:pax_index, params, session, socket),
        do: Pax.Index.Live.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_index}

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def pax_adapter(_socket) do
        raise """
        No pax_adapter/1 callback found for #{__MODULE__}.
        Please configure an adapter by defining a pax_adapter function, for example:

            def pax_adapter(_socket),
              do: {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}

        """
      end

      def pax_fields(_socket), do: nil

      defoverridable pax_init: 3, pax_adapter: 1, pax_fields: 1
    end
  end

  def on_mount(module, params, session, socket) do
    # IO.puts("#{__MODULE__}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    case module.pax_init(params, session, socket) do
      {:cont, socket} -> init(module, socket)
      {:halt, socket} -> {:halt, socket}
    end
  end

  defp init(module, socket) do
    # IO.puts("#{__MODULE__}.init(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    adapter = init_adapter(module, socket)
    fields = init_fields(module, adapter, socket)
    # plugins = init_plugins(module, params, sessions, socket)
    plugins = []

    socket =
      socket
      |> assign_pax(:module, module)
      |> assign_pax(:adapter, adapter)
      |> assign_pax(:plugins, plugins)
      |> assign_pax(:fields, fields)
      |> assign_pax(:singular_name, init_singular_name(module, adapter, socket))
      |> assign_pax(:plural_name, init_plural_name(module, adapter, socket))
      |> assign_pax(:new_path, init_new_path(module, socket))
      |> attach_hook(:pax_handle_params, :handle_params, fn params, uri, socket ->
        on_handle_params(module, adapter, plugins, fields, params, uri, socket)
      end)

    {:cont, socket}
  end

  def on_handle_params(module, adapter, _plugins, _fields, params, uri, socket) do
    # IO.puts("#{__MODULE__}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign_pax(:uri, URI.parse(uri))
      |> assign(:objects, Pax.Adapter.list_objects(adapter, params, uri, socket))

    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  # TODO: move to a shared module
  defp init_adapter(module, socket) do
    case module.pax_adapter(socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/1"
    end
  end

  defp init_fields(module, adapter, socket) do
    get_fields(module, adapter, socket)
    |> set_link_field_if_link_callback(module)
    |> Enum.map(&Pax.Field.init(module, adapter, &1))
  end

  defp get_fields(module, adapter, socket) do
    case module.pax_fields(socket) do
      fields when is_list(fields) -> fields
      nil -> Pax.Adapter.default_index_fields(adapter)
      _ -> raise ArgumentError, "Invalid fields returned from #{inspect(module)}.pax_fields/1"
    end
  end

  defp set_link_field_if_link_callback(fields, module) do
    # If a pax_field_link callback is defined, set the link field to the first field unless at least one field is
    # already set to link. This is so that if no fields are defined to link, but pax_field_link() is provided,
    # then make the first field linked by default.
    if function_exported?(module, :pax_field_link, 1) do
      fields |> Pax.Field.Util.maybe_set_default_link_field()
    else
      fields
    end
  end
end
