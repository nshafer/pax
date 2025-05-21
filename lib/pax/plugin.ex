defmodule Pax.Plugin do
  @moduledoc """
  Pax.Plugin is a behaviour for defining plugins that can be used with Pax.Interface or Pax.Admin. This is the base
  behavior that all Plugins must implement. However, most plugins will `use Pax.Interface.Plugin` or
  `use Pax.Admin.Plugin` instead of implementing this behaviour directly.
  """
  defstruct [:module, :type, :config_key, :opts]

  @typedoc "A Phoenix.LiveView socket"
  @type socket :: Phoenix.LiveView.Socket.t()

  @typedoc "The plugin specification, with or without init options"
  @type pluginspec :: module() | {module(), opts :: keyword()}

  @typedoc "The plugin struct"
  @type t :: %__MODULE__{module: module(), type: atom(), opts: map()}

  @doc "The type of plugin"
  @callback type() :: :interface | :admin

  @doc """
  The plugin initialization function, must return a map of initialized plugin state, which is passed to all other
  callback functions in the plugin.
  """
  @callback init(callback_module :: module(), opts :: keyword()) :: map()

  @doc "A function that returns the key for the plugin's configuration. Must be unique."
  @callback config_key() :: atom()

  @doc "A function that returns a valid Pax.Config spec for configuration keys and types accepted by the plugin."
  @callback config_spec() :: map()

  @doc "A function that merges any additional configuration options into the plugin's opts."
  @callback merge_config(opts :: map(), config :: map(), socket()) :: map()

  @doc "Render a plugin component."
  @callback render(opts :: map(), section :: atom(), assigns :: map()) ::
              Phoenix.LiveView.Rendered.t() | nil

  @doc """
  Initialize the given plugin with the provided callback module and options.
  """
  @spec init(callback_module :: module(), pluginspec()) :: t()
  def init(callback_module, plugin_module) when is_atom(plugin_module), do: do_init(callback_module, plugin_module, [])
  def init(callback_module, {plugin_module, opts}), do: do_init(callback_module, plugin_module, opts)

  defp do_init(callback_module, plugin_module, opts) do
    # Type must be an atom, and must not be nil
    type = plugin_module.type()

    if not is_atom(type) or is_nil(type) do
      raise ArgumentError, "Invalid plugin type returned from #{inspect(plugin_module)}.type/0"
    end

    # Config key must be an atom or nil (if the plugin doesn't have any config)
    config_key = plugin_module.config_key()

    if not is_atom(config_key) do
      raise ArgumentError, "Invalid config key returned from #{inspect(plugin_module)}.config_key/0"
    end

    # The plugin's init must return a map
    opts = plugin_module.init(callback_module, opts)

    if not is_map(opts) do
      raise ArgumentError, "Invalid plugin opts returned from #{inspect(plugin_module)}.init/2"
    end

    # Return the plugin struct
    %__MODULE__{
      module: plugin_module,
      type: type,
      config_key: config_key,
      opts: opts
    }
  end

  def config_key(%__MODULE__{} = plugin) do
    plugin.module.config_key()
  end

  def config_spec(%__MODULE__{} = plugin) do
    plugin.module.config_spec()
  end

  def merge_config(%__MODULE__{} = plugin, config, socket) do
    opts = plugin.module.merge_config(plugin.opts, config, socket)
    %{plugin | opts: opts}
  end

  @doc """
  Render plugins.

  You can define your own plugin sections in your interface, then create plugins that implement those areas.

      <div>
        {Pax.Plugin.render(:my_plugin_section, assigns)}
      </div>

  Then in your plugin, you can define a render function for that section.

      defmodule MyPaxInterfacePlugin do
        use Pax.Interface.Plugin
        use Phoenix.Component

        def render(_opts, :my_plugin_section, assigns) do
          ~H\"""
          <div>{@pax.plural_name}</div>
          \"""
        end
      end

  """

  # -----------------------------------------------
  # Optimized %Phoenix.LiveView.Rendered{} version
  # -----------------------------------------------
  # This version is an optimization of the "Dynamic heex template concatenation version" below. It avoids the cost of
  # building, compiling and evaluating a template at run-time, everywhere there is a plugin section. The resulting
  # code is more efficient, and works with change tracking, but builds a `%Phoenix.LiveView.Rendered{}` manually
  # so it could break in the future if there are changes in LiveView. If that happens, comment this out and uncomment
  # the "Dynamic heex template concatenation version" below.
  #
  # Note: `track_changes` is ignored since this just outputs a list of other `%Phoenix.LiveView.Rendered{}` elements
  # and so the Renderer will just pass the `track_changes?` boolean to each of them. We also don't care if changes are
  # being tracked or not, since we always the same list of dynamics, and the fingerprint is based on the
  # `@pax.plugins` list, so it will always be the same as long as the plugins don't change.
  #
  # Note: `root` is set to false, which was how it was set in the "Dynamic heex template concatenation version" below.

  def render(section, assigns) do
    %{plugins: plugins} = assigns.pax

    dynamic = fn _track_changes? ->
      for plugin <- plugins do
        plugin.module
        |> apply(:render, [plugin.opts, section, assigns])
        |> Phoenix.LiveView.Engine.live_to_iodata()
      end
    end

    %Phoenix.LiveView.Rendered{
      static: List.duplicate("", length(plugins) + 1),
      dynamic: dynamic,
      fingerprint: fingerprint(section, plugins),
      root: false
    }
  end

  defp fingerprint(section, plugins) do
    <<fingerprint::8*16>> =
      [section | plugins]
      |> :erlang.term_to_binary()
      |> :erlang.md5()

    fingerprint
  end

  # -----------------------------------------------
  # Dynamic heex template concatenation version
  # -----------------------------------------------
  # This version builds up a template at run-time consisting of function calls to each of the configured plugin's
  # `render/3` function, each in turn as if they had been hard coded in the template such as:application
  #
  #     {MyPlugin.render(opts, section, assigns)}
  #     {MyPlugin2.render(opts, section, assigns)}
  #
  # The huge advantage here is that it works with change tracking, since `assigns` is untouched. Therefore each
  # plugin section will only re-render if the assigns change, and not if the plugin list changes.
  #
  # This also works with "deep" change tracking, so it detects if the plugin section only accessed certain keys
  # of the `@pax` assign, for example.

  # This only uses the publicly available LV API, so it should be safe to use in production, but it is slow. It is
  # left here so that if changes in LV, and the optimized version stops working, then this can be quickly uncommented.

  # def render(section, assigns) do
  #   assigns = assign(assigns, :section, section)

  #   expr =
  #     assigns.pax.plugins
  #     |> Enum.map(fn plugin ->
  #       "{#{plugin.module}.render(#{inspect(plugin.opts)}, #{inspect(section)}, assigns)}"
  #     end)
  #     |> IO.iodata_to_binary()

  #   options = [
  #     engine: Phoenix.LiveView.TagEngine,
  #     file: __ENV__.file,
  #     line: __ENV__.line,
  #     caller: __ENV__,
  #     indentation: 0,
  #     source: expr,
  #     tag_handler: Phoenix.LiveView.HTMLEngine
  #   ]

  #   template = EEx.compile_string(expr, options)
  #   # Pax.Debug.write_ast(template, header: "Pax.Plugin.render/2")
  #   {result, _} = Code.eval_quoted(template, [assigns: assigns], options)
  #   result
  # end

  # -----------------------------------------------
  # Heex comprehension version
  # -----------------------------------------------
  # Due to how comprehensions work, this breaks change tracking and will cause every plugin section to rerender
  # due to the `@section` assign changing every time we invoke the plugin's `render/3` function.
  #
  # Note: this can't be fixed by not assigning `@section` in the comprehension, because if we just use the variable
  # as is, then LV detects it as a tainted variable and throws an error, and disables change tracking.
  #
  # This is left here to remind myself that I already tried this, figured out why it broke change tracking, and to
  # not try it again.

  # def render(section, assigns) do
  #   assigns = assign(assigns, :section, section)

  #   ~H"""
  #   <%= for plugin <- @pax.plugins do %>
  #     {apply(plugin.module, :render, [plugin.opts, @section, assigns])}
  #   <% end %>
  #   """
  #   #|> dbg_m()
  # end
end
