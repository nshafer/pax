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
        case plugin.config_key do
          nil -> plugins_config_spec
          key -> init_plugin_config_spec(plugins_config_spec, key, plugin)
        end
    end
  end

  defp init_plugin_config_spec(plugins_config_spec, key, plugin) do
    case Map.fetch(plugins_config_spec, key) do
      {:ok, _existing} ->
        raise ArgumentError, "plugin #{inspect(plugin.module)} defined duplicate config key #{inspect(key)}"

      :error ->
        # No duplicate, so add the plugin's config spec
        case Pax.Plugin.config_spec(plugin) do
          nil ->
            plugins_config_spec

          plugin_config_spec when is_map(plugin_config_spec) ->
            Map.put(plugins_config_spec, plugin.config_key, plugin_config_spec)

          _ ->
            raise ArgumentError, "invalid config spec returned from #{inspect(plugin.module)}.config_spec/0"
        end
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

  def init_id_fields(config, adapter, socket) do
    case Pax.Config.fetch(config, :id_fields, [socket]) do
      {:ok, id_fields} -> id_fields
      :error -> init_adapter_id_fields(adapter)
    end
  end

  defp init_adapter_id_fields(adapter) do
    case Pax.Adapter.id_fields(adapter) do
      nil -> Pax.Interface.Config.default_id_fields()
      fields -> fields
    end
  end

  def init_singular_name(config, adapter, socket) do
    case Config.fetch(config, :singular_name, [socket]) do
      {:ok, value} -> value
      :error -> init_adapter_singular_name(adapter)
    end
  end

  defp init_adapter_singular_name(adapter) do
    case Pax.Adapter.singular_name(adapter) do
      nil -> "Object"
      name -> name
    end
  end

  def init_plural_name(config, adapter, socket) do
    case Config.fetch(config, :plural_name, [socket]) do
      {:ok, value} -> value
      :error -> init_adapter_plural_name(adapter)
    end
  end

  defp init_adapter_plural_name(adapter) do
    case Pax.Adapter.plural_name(adapter) do
      nil -> "Objects"
      name -> name
    end
  end

  def init_object_name(nil, _socket), do: "Object"

  def init_object_name(object, socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    case Config.fetch(config, :object_name, [object, socket]) do
      {:ok, nil} -> init_adapter_object_name(adapter, object)
      {:ok, value} -> value
      :error -> init_adapter_object_name(adapter, object)
    end
  end

  defp init_adapter_object_name(adapter, object) do
    case Pax.Adapter.object_name(adapter, object) do
      nil -> "Object"
      name -> name
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

  def init_fields(action, socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax
    fields = get_fields(config, adapter, socket)

    # Iterate through the list of fieldspecs, initializing them with Pax.Field.init, then for any field
    # with `link: true` set it to the proper callback (`config.show_path` or `config.edit_path`). If there
    # are no fields with a link set, we'll make the first field a link if there is a config set, first
    # `config.show_path`, then `config.edit_path`.

    {fields, has_link} =
      for fieldspec <- fields, reduce: {[], false} do
        {fields, has_link} ->
          field =
            adapter
            |> Pax.Field.init(fieldspec)
            |> resolve_field_link(config, socket)

          {[field | fields], Map.has_key?(field.opts, :link) || has_link}
      end

    fields =
      fields
      |> Enum.reverse()
      |> fields_for_action(action)

    if has_link do
      fields
    else
      maybe_set_first_field_linked(fields, config, socket)
    end
  end

  defp get_fields(config, adapter, socket) do
    case Config.fetch(config, :fields, [socket]) do
      {:ok, fields} -> fields
      :error -> Pax.Adapter.default_fields(adapter)
    end
  end

  defp fields_for_action(fields, action) do
    fields
    |> Enum.filter(&filter_field_only(&1, action))
    |> Enum.reject(&reject_field_except(&1, action))
  end

  defp filter_field_only(field, action) do
    case Map.get(field.opts, :only) do
      nil -> true
      only when only == action -> true
      only when is_list(only) -> Enum.member?(only, action)
      _ -> false
    end
  end

  defp reject_field_except(field, action) do
    case Map.get(field.opts, :except) do
      nil -> false
      except when except == action -> true
      except when is_list(except) -> Enum.member?(except, action)
      _ -> false
    end
  end

  defp resolve_field_link(field, config, socket) do
    case Map.get(field.opts, :link) do
      # Convert a `link: true` field into a function call to the proper callback, otherwise raise an error
      true ->
        cond do
          config[:show_path] ->
            Pax.Field.set_link(field, fn object -> Config.get(config, :show_path, [object, socket]) end)

          config[:edit_path] ->
            Pax.Field.set_link(field, fn object -> Config.get(config, :edit_path, [object, socket]) end)

          true ->
            raise "You must configure either :show_path or :edit_path to use link: true"
        end

      # Otherwise just return the field as is if there is an explicit link set (callback, url, etc) or not.
      _link ->
        field
    end
  end

  defp maybe_set_first_field_linked([first_field | rest], config, socket) do
    first_field =
      cond do
        config[:show_path] ->
          Pax.Field.set_link(first_field, fn object -> Config.get(config, :show_path, [object, socket]) end)

        config[:edit_path] ->
          Pax.Field.set_link(first_field, fn object -> Config.get(config, :edit_path, [object, socket]) end)

        true ->
          first_field
      end

    [first_field | rest]
  end
end
