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

  # Common callbacks
  @callback pax_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback pax_adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback pax_plugins(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Plugin.pluginspec()]

  @callback pax_config(socket :: Phoenix.LiveView.Socket.t()) :: keyword() | map()

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Interface
      def on_mount(:pax_interface, params, session, socket),
        do: Pax.Interface.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_interface}

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def pax_adapter(_socket) do
        raise """
        No pax_adapter/1 callback found for #{inspect(__MODULE__)}.
        Please configure an adapter by defining a `pax_adapter/1` function, for example:

            def pax_adapter(_socket), do: Pax.Adapters.EctoSchema

        or

            def pax_adapter(_socket) do
              {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}
            end

        """
      end

      def pax_plugins(_socket), do: []

      def pax_config(_socket), do: []

      defoverridable pax_init: 3, pax_adapter: 1, pax_plugins: 1, pax_config: 1
    end
  end

  # Mount initialization

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
    config_spec = init_config_spec(adapter, plugins)
    config = init_config(config_spec, module, socket)
    adapter = merge_adapter_config(adapter, config, socket)
    plugins = merge_plugins_config(plugins, config, socket)

    socket =
      socket
      |> assign_pax(:config, config)
      |> assign_pax(:module, module)
      |> assign_pax(:adapter, adapter)
      |> assign_pax(:plugins, plugins)
      |> assign_pax(:id_fields, init_id_fields(config, adapter, socket))
      |> assign_pax(:singular_name, init_singular_name(config, adapter, socket))
      |> assign_pax(:plural_name, init_plural_name(config, adapter, socket))
      |> assign_pax(:index_path, init_index_path(config, socket))
      |> assign_pax(:new_path, init_new_path(config, socket))
      |> attach_hook(:pax_handle_params, :handle_params, fn params, uri, socket ->
        handle_params(params, uri, socket)
      end)
      |> attach_hook(:pax_handle_event, :handle_event, fn event, params, socket ->
        handle_event(event, params, socket)
      end)
      |> attach_hook(:pax_handle_info, :handle_info, fn msg, socket ->
        handle_info(msg, socket)
      end)
      |> attach_hook(:pax_handle_async, :handle_async, fn name, async_fun_result, socket ->
        handle_async(name, async_fun_result, socket)
      end)
      |> attach_hook(:pax_after_render, :after_render, fn socket ->
        after_render(socket)
      end)

    {:cont, socket}
  end

  # handle_params
  #
  # This is the main entry point for the `:handle_params` hook.

  defp handle_params(params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)})")

    with(
      {:cont, socket} <- global_handle_params(params, uri, socket),
      {:cont, socket} <- plugin_handle_params(params, uri, socket, :on_preload),
      {:cont, socket} <- action_handle_params(params, uri, socket),
      {:cont, socket} <- plugin_handle_params(params, uri, socket, :on_loaded),
      {:cont, socket} <- module_handle_params(params, uri, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
    end
  end

  defp global_handle_params(_params, uri, socket) do
    # Parse the URI of the current request
    url = URI.parse(uri)

    # Extract just the path and query from the URL. Fragment should never be set here, but...
    path = %URI{path: url.path, query: url.query, fragment: url.fragment}

    socket =
      socket
      |> assign_pax(:url, url)
      |> assign_pax(:path, path)
      |> assign_pax(:action, socket.assigns.live_action)
      |> assign_pax(:fields, init_fields(socket.assigns.live_action, socket))

    {:cont, socket}
  end

  defp action_handle_params(params, uri, socket) do
    case socket.assigns.pax.action do
      :index -> Index.on_params(params, uri, socket)
      :show -> Detail.on_params(params, uri, socket)
      :edit -> Detail.on_params(params, uri, socket)
      :new -> Detail.on_params(params, uri, socket)
      :delete -> raise "Delete action not implemented"
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_params(params, uri, socket, callback) do
    %{plugins: plugins} = socket.assigns.pax

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

  # This check is needed because if LiveView detects a `patch` navigation, then it will call handle_params, such as
  # when we or plugins do a `push_patch`, or `<.link patch=...>`. If the user has not defined a handle_params callback,
  # then we want to tell LiveView to halt, otherwise it will attempt to call the user module's handle_params callback,
  # which may not exist, and will raise an error.
  defp module_handle_params(_params, _uri, socket) do
    %{module: module} = socket.assigns.pax

    # If the user has defined a handle_params callback, then we need to return {:cont, socket} so that Phoenix.LiveView
    # will call it, otherwise we tell Phoenix.LiveView to halt.
    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  # handle_event
  #
  # This is the main entry point for the `:handle_event` hook.

  defp handle_event(event, params, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_event(#{inspect(event)}, #{inspect(params)})")

    with(
      {:cont, socket} <- action_handle_event(event, params, socket),
      {:cont, socket} <- plugin_handle_event(event, params, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
      {:halt, reply, socket} -> {:halt, reply, socket}
    end
  end

  def action_handle_event(event, params, socket) do
    case socket.assigns.pax.action do
      # Index doesn't handle any events for now, skip it
      # :index -> Index.on_event(event, params, socket)
      :new -> Detail.on_event(event, params, socket)
      :show -> Detail.on_event(event, params, socket)
      :edit -> Detail.on_event(event, params, socket)
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_event(event, params, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :on_event, 4) do
        case plugin.module.on_event(plugin.opts, event, params, socket) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
          {:halt, reply, socket} -> {:halt, {:halt, reply, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
  end

  # handle_info
  #
  # This is the main entry point for the `:handle_info` hook.

  defp handle_info(msg, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_info(#{inspect(msg)})")

    with(
      # Action modules don't handle info messages for now, skip it
      # {:cont, socket} <- action_handle_info(msg, socket),
      {:cont, socket} <- plugin_handle_info(msg, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
    end
  end

  def action_handle_info(msg, socket) do
    case socket.assigns.pax.action do
      :index -> Index.on_info(msg, socket)
      :new -> Detail.on_info(msg, socket)
      :show -> Detail.on_info(msg, socket)
      :edit -> Detail.on_info(msg, socket)
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_info(msg, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :on_info, 3) do
        case plugin.module.on_info(plugin.opts, msg, socket) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
  end

  # handle_async
  #
  # This is the main entry point for the `:handle_async` hook.

  defp handle_async(name, async_fun_result, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_async(#{inspect(name)}, #{inspect(async_fun_result)})")

    with(
      # {:cont, socket} <- action_handle_async(name, async_fun_result, socket),
      {:cont, socket} <- plugin_handle_async(name, async_fun_result, socket)
    ) do
      {:cont, socket}
    else
      {:halt, socket} -> {:halt, socket}
    end
  end

  def action_handle_async(name, async_fun_result, socket) do
    case socket.assigns.pax.action do
      :index -> Index.on_async(name, async_fun_result, socket)
      :new -> Detail.on_async(name, async_fun_result, socket)
      :show -> Detail.on_async(name, async_fun_result, socket)
      :edit -> Detail.on_async(name, async_fun_result, socket)
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_async(name, async_fun_result, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :on_async, 4) do
        case plugin.module.on_async(plugin.opts, name, async_fun_result, socket) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
  end

  # after_render
  #
  # This is the main entry point for the `:after_render` hook.

  defp after_render(socket) do
    # IO.puts("#{inspect(__MODULE__)}.after_render()")

    socket
    |> action_after_render()
    |> plugin_after_render()
  end

  def action_after_render(socket) do
    case socket.assigns.pax.action do
      :index -> Index.after_render(socket)
      # Detail does not do anything after render for now, skip it
      # :new -> Detail.after_render(socket)
      # :show -> Detail.after_render(socket)
      # :edit -> Detail.after_render(socket)
      _ -> socket
    end
  end

  defp plugin_after_render(socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce(plugins, socket, fn plugin, socket ->
      if function_exported?(plugin.module, :after_render, 2) do
        plugin.module.after_render(plugin.opts, socket)
      else
        socket
      end
    end)
  end
end
