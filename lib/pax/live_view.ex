defmodule Pax.LiveView do
  @moduledoc """
  Pax.LiveView is a behaviour and set of utilities for building more specific Pax.Index.Live and Pax.Detail.Live
  modules. It is not meant to be used by itself.
  """
  import Phoenix.Component, only: [assign: 3]

  @callback pax_pre_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback pax_post_init(socket :: Phoenix.LiveView.Socket.t()) ::
              {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback pax_adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback pax_singular_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_plural_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_object_name(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()

  @optional_callbacks pax_singular_name: 1, pax_plural_name: 1, pax_object_name: 2

  @callback pax_index_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_new_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_show_path(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()
  @callback pax_edit_path(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()

  @optional_callbacks pax_index_path: 1, pax_new_path: 1, pax_show_path: 2, pax_edit_path: 2

  defmacro __using__(_opts) do
    quote do
      def on_mount(:pax_live_view, params, session, socket),
        do: Pax.LiveView.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_live_view}

      # IO.puts("Pax.LiveView.__using__ for #{inspect(__MODULE__)}")
      def pax_pre_init(_params, _session, socket), do: {:cont, socket}

      def pax_internal_init(_module, socket), do: {:cont, socket}

      def pax_post_init(socket), do: {:cont, socket}

      def pax_adapter(_socket) do
        raise """
        No pax_adapter/1 callback found for #{inspect(__MODULE__)}.
        Please configure an adapter by defining a pax_adapter function, for example:

            def pax_adapter(_socket),
              do: {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}

        """
      end

      defoverridable pax_pre_init: 3, pax_internal_init: 2, pax_post_init: 1, pax_adapter: 1
    end
  end

  def on_mount(module, params, session, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    case module.pax_pre_init(params, session, socket) do
      {:cont, socket} -> init(module, socket)
      {:halt, socket} -> {:halt, socket}
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

    case module.pax_internal_init(module, socket) do
      {:cont, socket} -> module.pax_post_init(socket)
      {:halt, socket} -> {:halt, socket}
    end
  end

  @doc false
  defp init_adapter(module, socket) do
    case module.pax_adapter(socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/1"
    end
  end

  def assign_pax(socket_or_assigns, key, value)

  def assign_pax(%Phoenix.LiveView.Socket{} = socket, key, value) do
    pax =
      socket.assigns
      |> Map.get(:pax, %{})
      |> Map.put(key, value)

    assign(socket, :pax, pax)
  end

  def assign_pax(%{} = assigns, key, value) do
    pax =
      assigns
      |> Map.get(:pax, %{})
      |> Map.put(key, value)

    assign(assigns, :pax, pax)
  end

  def assign_pax(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax(acc, key, value)
    end)
  end

  def init_singular_name(module, adapter, socket) do
    if function_exported?(module, :pax_singular_name, 1) do
      module.pax_singular_name(socket)
    else
      Pax.Adapter.singular_name(adapter)
    end
  end

  def init_plural_name(module, adapter, socket) do
    if function_exported?(module, :pax_plural_name, 1) do
      module.pax_plural_name(socket)
    else
      Pax.Adapter.plural_name(adapter)
    end
  end

  def init_object_name(_module, _adapter, _socket, nil), do: "Object"

  def init_object_name(module, adapter, socket, object) do
    if function_exported?(module, :pax_object_name, 2) do
      module.pax_object_name(socket, object)
    else
      Pax.Adapter.object_name(adapter, object)
    end
  end

  def init_index_path(module, socket) do
    if function_exported?(module, :pax_index_path, 1) do
      module.pax_index_path(socket)
    else
      nil
    end
  end

  def init_new_path(module, socket) do
    if function_exported?(module, :pax_new_path, 1) do
      module.pax_new_path(socket)
    else
      nil
    end
  end

  def init_show_path(module, socket, object) do
    if function_exported?(module, :pax_show_path, 2) do
      module.pax_show_path(socket, object)
    else
      nil
    end
  end

  def init_edit_path(module, socket, object) do
    if function_exported?(module, :pax_edit_path, 2) do
      module.pax_edit_path(socket, object)
    else
      nil
    end
  end
end
