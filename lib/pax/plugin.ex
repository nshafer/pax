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

  @doc "A function that returns the key for the plugin's configuration. Must be unique."
  @callback config_key() :: atom()

  @doc "A function that returns a valid Pax.Config spec for configuration keys and types accepted by the plugin."
  @callback config_spec() :: map()

  @doc "A function that merges any additional configuration options into the plugin's opts."
  @callback merge_config(opts :: map(), config :: map(), socket()) :: map()

  @doc "The type of plugin"
  @callback type() :: :interface | :admin

  @doc """
  The plugin initialization function, must return a map of initialized plugin state, which is passed to all other
  callback functions in the plugin.
  """
  @callback init(callback_module :: module(), opts :: keyword()) :: map()

  @doc """
  Initialize the given plugin with the provided callback module and options.
  """
  @spec init(callback_module :: module(), pluginspec()) :: t()
  def init(callback_module, plugin_module) when is_atom(plugin_module), do: do_init(callback_module, plugin_module, [])
  def init(callback_module, {plugin_module, opts}), do: do_init(callback_module, plugin_module, opts)

  defp do_init(callback_module, plugin_module, opts) do
    %__MODULE__{
      module: plugin_module,
      type: plugin_module.type(),
      config_key: plugin_module.config_key(),
      opts: plugin_module.init(callback_module, opts)
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
end
