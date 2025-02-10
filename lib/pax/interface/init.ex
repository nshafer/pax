defmodule Pax.Interface.Init do
  @moduledoc false

  alias Pax.Config

  def init_adapter(module, socket) do
    case module.pax_adapter(socket) do
      {adapter_module, callback_module, opts} -> Pax.Adapter.init(adapter_module, callback_module, opts)
      {adapter_module, opts} -> Pax.Adapter.init(adapter_module, module, opts)
      adapter_module when is_atom(adapter_module) -> Pax.Adapter.init(adapter_module, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/1"
    end
  end

  def merge_adapter_config(adapter, config, socket) do
    adapter_config = Map.get(config, :adapter, %{})
    Pax.Adapter.merge_config(adapter, adapter_config, socket)
  end

  def init_plugins(module, socket) do
    for pluginspec <- get_plugins(module, socket) do
      Pax.Plugin.init(module, pluginspec)
    end
  end

  def merge_plugins_config(plugins, config, socket) do
    plugins_config = Map.get(config, :plugins, %{})

    Enum.map(plugins, fn plugin ->
      plugin_config = Map.get(plugins_config, plugin.config_key, %{})
      Pax.Plugin.merge_config(plugin, plugin_config, socket)
    end)
  end

  defp get_plugins(module, socket) do
    case module.pax_plugins(socket) do
      plugins when is_list(plugins) -> plugins
      _ -> raise ArgumentError, "Invalid plugins returned from #{inspect(module)}.plugins/1"
    end
  end

  def init_config_spec(adapter, plugins) do
    # TODO: get config_spec from module, so things like admin can add additional config
    config_spec = Pax.Interface.Config.config_spec()
    adapter_config_spec = Pax.Adapter.config_spec(adapter)
    plugins_config_spec = init_plugins_config_spec(plugins)

    config_spec
    |> Map.put(:adapter, adapter_config_spec)
    |> Map.put(:plugins, plugins_config_spec)
  end

  def init_plugins_config_spec(plugins) do
    for plugin <- plugins, reduce: %{} do
      plugins_config_spec ->
        plugin_config_spec = Pax.Plugin.config_spec(plugin)

        if Map.has_key?(plugins_config_spec, plugin.config_key) do
          raise ArgumentError,
                "plugin #{inspect(plugin)} defined duplicate config spec for #{inspect(plugin.config_key)}, " <>
                  "already defined as #{inspect(Map.get(plugins_config_spec, plugin.config_key))}"
        end

        Map.put(plugins_config_spec, plugin.config_key, plugin_config_spec)
    end
  end

  def init_config(config_spec, module, socket) do
    config_data = get_module_config(module, socket)
    Pax.Config.validate!(config_spec, config_data)
  end

  def get_module_config(module, socket) do
    case module.pax_config(socket) do
      config when is_map(config) or is_list(config) -> config
      _ -> raise ArgumentError, "invalid config returned from #{inspect(module)}.pax_config/1"
    end
  end

  def init_singular_name(config, adapter, socket) do
    case Config.fetch(config, :singular_name, [socket]) do
      {:ok, value} -> value
      :error -> Pax.Adapter.singular_name(adapter)
    end
  end

  def init_plural_name(config, adapter, socket) do
    case Config.fetch(config, :plural_name, [socket]) do
      {:ok, value} -> value
      :error -> Pax.Adapter.plural_name(adapter)
    end
  end

  def init_object_name(_config, _adapter, nil, _socket), do: "Object"

  def init_object_name(config, adapter, object, socket) do
    case Config.fetch(config, :object_name, [object, socket]) do
      {:ok, nil} -> Pax.Adapter.object_name(adapter, object)
      {:ok, value} -> value
      :error -> Pax.Adapter.object_name(adapter, object)
    end
  end

  def init_index_path(config, socket) do
    case Config.fetch(config, :index_path, [socket]) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  def init_new_path(config, socket) do
    case Config.fetch(config, :new_path, [socket]) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  def init_show_path(config, object, socket) do
    case Config.fetch(config, :show_path, [object, socket]) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  def init_edit_path(config, object, socket) do
    case Config.fetch(config, :edit_path, [object, socket]) do
      {:ok, value} -> value
      :error -> nil
    end
  end
end
