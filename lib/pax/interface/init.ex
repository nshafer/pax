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
    Pax.Adapter.merge_config(adapter, config, socket)
  end

  def init_plugins(module, socket) do
    for pluginspec <- get_plugins(module, socket) do
      Pax.Plugin.init(module, pluginspec)
    end
  end

  def merge_plugins_config(plugins, config, socket) do
    Enum.map(plugins, fn plugin -> Pax.Plugin.merge_config(plugin, config, socket) end)
  end

  defp get_plugins(module, socket) do
    case module.pax_plugins(socket) do
      plugins when is_list(plugins) -> plugins
      _ -> raise ArgumentError, "Invalid plugins returned from #{inspect(module)}.plugins/1"
    end
  end

  def init_config_spec(adapter, plugins) do
    config_spec = Pax.Interface.Config.config_spec()
    adapter_config_spec = Pax.Adapter.config_spec(adapter)

    config_spec =
      Map.merge(config_spec, adapter_config_spec, fn key, val1, val2 ->
        unless val1 == val2 do
          raise ArgumentError,
                "adapter defined duplicate config spec for #{inspect(key)}, " <>
                  "already defined as #{inspect(val1)}"
        end
      end)

    for plugin <- plugins, reduce: config_spec do
      config_spec ->
        plugin_config_spec = Pax.Plugin.config_spec(plugin)

        Map.merge(config_spec, plugin_config_spec, fn key, val1, val2 ->
          unless val1 == val2 do
            raise ArgumentError,
                  "plugin #{inspect(plugin)} defined duplicate config spec for #{inspect(key)}, " <>
                    "already defined as #{inspect(val1)}"
          end
        end)
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
