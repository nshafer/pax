defmodule Pax.Plugin do
  @moduledoc """
  Pax.Plugin is a behaviour for defining plugins that can be used with Pax.Interface or Pax.Admin. This is the base
  behavior that all Plugins must implement. However, most plugins will `use Pax.Interface.Plugin` or
  `use Pax.Admin.Plugin` instead of implementing this behaviour directly.
  """
  defstruct [:module, :type, :opts]

  @typedoc "The plugin specification, with or without init options"
  @type pluginspec :: module() | {module(), opts :: keyword()}

  @typedoc "The plugin struct"
  @type t :: %__MODULE__{module: module(), type: atom(), opts: map()}

  @doc "A function that returns a valid Pax.Config spec for configuration keys and types accepted by the plugin."
  @callback config_spec() :: map()

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
      opts: plugin_module.init(callback_module, opts)
    }
  end

  def config_spec(%__MODULE__{} = plugin) do
    plugin.module.config_spec()
  end
end
