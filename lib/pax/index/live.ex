defmodule Pax.Index.Live do
  use Phoenix.Component
  import Phoenix.LiveView

  def on_mount(module, _params, _session, socket) do
    check_adapter(module)

    socket =
      socket
      |> assign(:pax_module, module)
      |> attach_hook(:pax_index_handle_params, :handle_params, &on_handle_params/3)

    {:cont, socket}
  end

  def on_handle_params(_params, _uri, socket) do
    {:cont, socket |> assign_objects()}
  end

  defp assign_objects(socket) do
    module = socket.assigns.pax_module
    {adapter, adapter_opts} = module.__pax__(:adapter)
    assign(socket, :objects, adapter.list_objects(adapter_opts, socket))
  end

  defmacro __using__(opts) do
    quote do
      IO.puts("Pax.Index.Live.__using__ for #{inspect(__MODULE__)}")

      unquote(config(opts))
      unquote(components(opts))
      unquote(render())
    end
  end

  defp config(opts) do
    quote bind_quoted: [opts: opts] do
      @pax_otp_app Keyword.get(opts, :otp_app) || raise("otp_app is required")
      @pax_adapter nil
      # @pax_fields []
      Module.register_attribute(__MODULE__, :pax_fields, accumulate: true)

      use Phoenix.LiveView, Keyword.take(opts, [:container, :global_prefixes, :layout, :log, :namespace])
      import Pax.Index.Live, only: [adapter: 1, adapter: 2, field: 2, field: 3]

      def on_mount(:pax_index, params, session, socket),
        do: Pax.Index.Live.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_index}

      @before_compile Pax.Index.Live
    end
  end

  defp components(opts) do
    components = Keyword.get(opts, :components) || Pax.Index.DefaultComponents

    quote do
      @pax_components unquote(components)
      import unquote(components)
    end
  end

  defp render() do
    quote unquote: false do
      def render(var!(assigns)) do
        ~H"""
        <.pax_index pax_module={@pax_module} objects={@objects} />
        """
      end

      defoverridable render: 1
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    IO.puts("Pax.Index.Live.__before_compile__ for #{inspect(env.module)}")

    quote do
      def __pax__(:type), do: :index
      def __pax__(:otp_app), do: @pax_otp_app
      def __pax__(:adapter), do: @pax_adapter
      def __pax__(:components), do: @pax_components
      def __pax__(:fields), do: @pax_fields |> Enum.reverse()

      def __pax__(:config), do: Application.get_env(@pax_otp_app, Pax, [])
      def __pax__(:config, key, default \\ nil), do: Keyword.get(__pax__(:config), key, default)
    end
  end

  defmacro adapter(adapter, opts \\ []) do
    quote do
      @pax_adapter {unquote(adapter), unquote(adapter).init(__MODULE__, unquote(opts))}
    end
  end

  defp check_adapter(module) do
    if module.__pax__(:adapter) == nil do
      raise """
      No adapter configured for #{module}.
      Please configure an adapter by using the adapter macro, for example:

          defmodule #{module} do
            use Pax.Index.Live

            adapter Pax.Index.SchemaAdapter, schema: MyApp.MySchema
          end

      """
    end
  end

  defmacro field(name, type, opts \\ []) do
    # TODO: support anonymous functions for the value opt. Do this by converting it into a function in the caller's
    #       module, then just storing the MFA to it.
    # TODO: add field/2 macro that gets the type and opts from the adapter
    quote do
      Pax.Index.Live.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  def __field__(mod, name, type, opts) do
    {type, opts} = Pax.Index.Field.init(mod, type, opts)
    Module.put_attribute(mod, :pax_fields, {name, type, opts})
  end

  def fields(mod) do
    mod.__pax__(:fields)
  end
end
