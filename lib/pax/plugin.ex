defmodule Pax.Plugin do
  @type pluginspec :: module() | {module(), opts :: keyword()}
  @type t :: %__MODULE__{module: module(), type: atom(), opts: map()}

  defstruct [:module, :type, :opts]

  @callback type() :: atom()
  @callback init(callback_module :: module(), opts :: keyword()) :: map()

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

  @doc """
  Gets an option from either the provided opts keyword list, or from an optionally defined callback of the same name.
  """
  def get_plugin_opt(callback_module, opts, key, default \\ nil)
      when is_atom(callback_module) and is_list(opts) and is_atom(key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} ->
        value

      :error ->
        if function_exported?(callback_module, key, 0) do
          apply(callback_module, key, [])
        else
          default
        end
    end
  end
end
