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
      import Pax.Interface.Context

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

      # This is a noop so that when we issue patch requests the user's LiveView doesn't crash if it's not defined.
      def handle_params(_params, _uri, socket), do: {:noreply, socket}
      defoverridable handle_params: 3
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
      |> attach_hook(:pax_handle_params, :handle_params, &handle_params/3)
      |> attach_hook(:pax_handle_event, :handle_event, &handle_event/3)
      |> attach_hook(:pax_handle_info, :handle_info, &handle_info/2)
      |> attach_hook(:pax_handle_async, :handle_async, &handle_async/3)
      |> attach_hook(:pax_after_render, :after_render, &after_render/1)

    {:cont, socket}
  end

  # handle_params
  #
  # This is the main entry point for the `:handle_params` hook.

  defp handle_params(params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)})")

    with(
      {:cont, socket} <- global_handle_params(params, uri, socket),
      {:cont, socket} <- plugin_handle_params(params, uri, socket),
      {:cont, socket} <- action_handle_params(params, uri, socket),
      {:cont, socket} <- plugin_after_params(socket)
    ) do
      {:cont, socket}
    end
  end

  defp global_handle_params(params, uri, socket) do
    socket =
      socket
      |> assign_action()
      |> assign_path(uri)
      |> assign_id_fields()
      |> assign_fields()
      |> assign_singular_name()
      |> assign_plural_name()
      |> assign_index_path(params)
      |> assign_new_path(params)
      |> assign_default_scope()

    {:cont, socket}
  end

  defp action_handle_params(params, uri, socket) do
    case socket.assigns.pax.action do
      :index -> Index.handle_params(params, uri, socket)
      :show -> Detail.handle_params(params, uri, socket)
      :edit -> Detail.handle_params(params, uri, socket)
      :new -> Detail.handle_params(params, uri, socket)
      :delete -> raise "Delete action not implemented"
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_params(params, uri, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :handle_params, 4) do
        case apply(plugin.module, :handle_params, [plugin.opts, params, uri, socket]) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
  end

  defp plugin_after_params(socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :after_params, 2) do
        case apply(plugin.module, :after_params, [plugin.opts, socket]) do
          {:cont, socket} -> {:cont, {:cont, socket}}
          {:halt, socket} -> {:halt, {:halt, socket}}
        end
      else
        {:cont, {:cont, socket}}
      end
    end)
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
      # :index -> Index.handle_event(event, params, socket)
      :new -> Detail.handle_event(event, params, socket)
      :show -> Detail.handle_event(event, params, socket)
      :edit -> Detail.handle_event(event, params, socket)
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_event(event, params, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :handle_event, 4) do
        case plugin.module.handle_event(plugin.opts, event, params, socket) do
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
      :index -> Index.handle_info(msg, socket)
      :new -> Detail.handle_info(msg, socket)
      :show -> Detail.handle_info(msg, socket)
      :edit -> Detail.handle_info(msg, socket)
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_info(msg, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :handle_info, 3) do
        case plugin.module.handle_info(plugin.opts, msg, socket) do
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
      :index -> Index.handle_async(name, async_fun_result, socket)
      :new -> Detail.handle_async(name, async_fun_result, socket)
      :show -> Detail.handle_async(name, async_fun_result, socket)
      :edit -> Detail.handle_async(name, async_fun_result, socket)
      _ -> {:cont, socket}
    end
  end

  defp plugin_handle_async(name, async_fun_result, socket) do
    %{plugins: plugins} = socket.assigns.pax

    Enum.reduce_while(plugins, {:cont, socket}, fn plugin, {:cont, socket} ->
      if function_exported?(plugin.module, :handle_async, 4) do
        case plugin.module.handle_async(plugin.opts, name, async_fun_result, socket) do
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
