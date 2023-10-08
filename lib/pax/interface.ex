defmodule Pax.Interface do
  @moduledoc """
  Pax.Interface enables the creation of CRUD interfaces based on Phoenix.LiveView.
  """
  import Phoenix.LiveView
  require Logger

  import Pax.Interface.Init
  import Pax.Interface.Util
  alias Pax.Interface.Index
  alias Pax.Interface.Detail

  @type fieldsets ::
          list(Pax.Field.fieldspec())
          | list(list(Pax.Field.fieldspec()) | Pax.Field.fieldspec())
          | keyword(list(Pax.Field.fieldspec()))

  # Common callbacks
  @callback pax_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback singular_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback plural_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback object_name(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t()

  @optional_callbacks singular_name: 1, plural_name: 1, object_name: 2

  @callback index_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback new_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback show_path(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback edit_path(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t()

  @optional_callbacks index_path: 1, new_path: 1, show_path: 2, edit_path: 2

  # Index callbacks
  @callback index_fields(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Field.fieldspec()] | nil

  # Detail callbacks
  @callback fieldsets(socket :: Phoenix.LiveView.Socket.t()) :: fieldsets() | nil

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Interface
      def on_mount(:pax_interface, params, session, socket),
        do: Pax.Interface.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_interface}

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def adapter(_socket) do
        raise """
        No adapter/1 callback found for #{inspect(__MODULE__)}.
        Please configure an adapter by defining a adapter function, for example:

            def adapter(_socket),
              do: {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}

        """
      end

      defoverridable pax_init: 3, adapter: 1

      # Default :index callbacks
      def index_fields(_socket), do: nil
      defoverridable index_fields: 1

      # Default :new, :show, :edit callbacks
      def fieldsets(_socket), do: nil
      defoverridable fieldsets: 1
    end
  end

  def on_mount(module, params, session, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    # module.pax_init can return {:halt, socket} to halt the pax initialization process, but we don't want to halt the
    # mount process, so we will always return {:cont, socket}. If the user wants to halt the mount after calling
    # a redirect, then they will need to do so in their own mount callback.

    with(
      {:cont, socket} <- module.pax_init(params, session, socket),
      {:cont, socket} <- init(module, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:cont, socket}
    end
  end

  defp init(module, socket) do
    adapter = init_adapter(module, socket)
    plugins = []

    socket =
      socket
      |> assign_pax(:module, module)
      |> assign_pax(:adapter, adapter)
      |> assign_pax(:plugins, plugins)
      |> assign_pax(:singular_name, init_singular_name(module, adapter, socket))
      |> assign_pax(:plural_name, init_plural_name(module, adapter, socket))
      |> assign_pax(:index_path, init_index_path(module, socket))
      |> assign_pax(:new_path, init_new_path(module, socket))
      |> attach_hook(:pax_handle_params, :handle_params, fn params, uri, socket ->
        on_handle_params(module, adapter, params, uri, socket)
      end)
      |> attach_hook(:pax_handle_event, :handle_event, fn event, params, socket ->
        on_handle_event(module, adapter, event, params, socket)
      end)

    {:cont, socket}
  end

  defp on_handle_params(module, adapter, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")

    with(
      {:cont, socket} <- global_handle_params(module, adapter, params, uri, socket),
      {:cont, socket} <- action_handle_params(module, adapter, params, uri, socket),
      {:cont, socket} <- module_handle_params(module, adapter, params, uri, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
    end
  end

  defp global_handle_params(_module, _adapter, _params, uri, socket) do
    {:cont,
     socket
     |> assign_pax(:uri, URI.parse(uri))}
  end

  defp action_handle_params(module, adapter, params, uri, socket) do
    case socket.assigns.live_action do
      :index -> Index.on_handle_params(module, adapter, params, uri, socket)
      :new -> Detail.on_handle_params(module, adapter, params, uri, socket)
      :show -> Detail.on_handle_params(module, adapter, params, uri, socket)
      :edit -> Detail.on_handle_params(module, adapter, params, uri, socket)
      _ -> {:cont, socket}
    end
  end

  defp module_handle_params(module, _adapter, _params, _uri, socket) do
    # If the user has defined a handle_params callback, then we need to return {:cont, socket} so that Phoenix.LiveView
    # will call it, otherwise we tell Phoenix.LiveView to halt.
    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  defp on_handle_event(module, adapter, event, params, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_event(#{inspect(module)}, #{inspect(event)}, #{inspect(params)}")

    case socket.assigns.live_action do
      :index -> Index.on_handle_event(module, adapter, event, params, socket)
      :new -> Detail.on_handle_event(module, adapter, event, params, socket)
      :show -> Detail.on_handle_event(module, adapter, event, params, socket)
      :edit -> Detail.on_handle_event(module, adapter, event, params, socket)
    end
  end
end
