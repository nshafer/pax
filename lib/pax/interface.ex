defmodule Pax.Interface do
  @moduledoc """
  Pax.Interface enables the creation of CRUD interfaces based on Phoenix.LiveView.
  """
  import Phoenix.LiveView
  require Logger

  import Pax.Interface.Init
  import Pax.Interface.Context
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

  @callback plugins(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Plugin.pluginspec()]

  @callback singular_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback plural_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback object_name(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @optional_callbacks singular_name: 1, plural_name: 1, object_name: 2

  @callback index_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback new_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback show_path(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback edit_path(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
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

      def plugins(_socket), do: []

      defoverridable pax_init: 3, adapter: 1, plugins: 1

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
    plugins = init_plugins(module, socket)

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
        handle_params(module, adapter, plugins, params, uri, socket)
      end)
      |> attach_hook(:pax_handle_event, :handle_event, fn event, params, socket ->
        handle_event(module, adapter, plugins, event, params, socket)
      end)

    {:cont, socket}
  end

  defp handle_params(module, adapter, plugins, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")

    with(
      {:cont, socket} <- global_handle_params(module, adapter, plugins, params, uri, socket),
      {:cont, socket} <- plugin_handle_params(module, adapter, plugins, params, uri, socket, :on_preload),
      {:cont, socket} <- action_handle_params(module, adapter, plugins, params, uri, socket),
      {:cont, socket} <- plugin_handle_params(module, adapter, plugins, params, uri, socket, :on_loaded),
      {:cont, socket} <- module_handle_params(module, adapter, plugins, params, uri, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
    end
  end

  defp global_handle_params(_module, _adapter, _plugins, _params, uri, socket) do
    # Parse the URI of the current request
    url = URI.parse(uri)

    # Extract just the path and query from the URL. Fragment should never be set here, but...
    path = %URI{path: url.path, query: url.query, fragment: url.fragment}

    socket =
      socket
      |> assign_pax(:url, url)
      |> assign_pax(:path, path)

    {:cont, socket}
  end

  defp plugin_handle_params(_module, _adapter, plugins, params, uri, socket, callback) do
    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, callback, 4) do
        case apply(plugin.module, callback, [plugin.opts, params, uri, socket]) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
  end

  defp action_handle_params(module, adapter, _plugins, params, uri, socket) do
    case socket.assigns.live_action do
      :index -> Index.on_params(module, adapter, params, uri, socket)
      :new -> Detail.on_params(module, adapter, params, uri, socket)
      :show -> Detail.on_params(module, adapter, params, uri, socket)
      :edit -> Detail.on_params(module, adapter, params, uri, socket)
      _ -> {:cont, socket}
    end
  end

  defp module_handle_params(module, _adapter, _plugins, _params, _uri, socket) do
    # If the user has defined a handle_params callback, then we need to return {:cont, socket} so that Phoenix.LiveView
    # will call it, otherwise we tell Phoenix.LiveView to halt.
    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  defp handle_event(module, adapter, plugins, event, params, socket) do
    IO.puts("#{inspect(__MODULE__)}.handle_event(#{inspect(module)}, #{inspect(event)}, #{inspect(params)}")

    with(
      {:cont, socket} <- action_handle_event(module, adapter, plugins, event, params, socket),
      {:cont, socket} <- plugin_handle_event(module, adapter, plugins, event, params, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
    end
  end

  def action_handle_event(module, adapter, _plugins, event, params, socket) do
    case socket.assigns.live_action do
      :index -> Index.on_event(module, adapter, event, params, socket)
      :new -> Detail.on_event(module, adapter, event, params, socket)
      :show -> Detail.on_event(module, adapter, event, params, socket)
      :edit -> Detail.on_event(module, adapter, event, params, socket)
    end
  end

  defp plugin_handle_event(_module, _adapter, plugins, event, params, socket) do
    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :on_event, 4) do
        case plugin.module.on_event(event, plugin.opts, params, socket) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
          {:halt, reply, socket} -> {:halt, {:halt, reply, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
  end
end
