defmodule Pax.Interface.Init do
  @moduledoc false

  import Pax.Interface.Context
  alias Pax.Config

  #
  # Interface init helpers
  #

  def init_adapter(module, socket) do
    case module.pax_adapter(socket) do
      nil -> nil
      adapter_module when is_atom(adapter_module) -> Pax.Adapter.init(adapter_module, module, [])
      {adapter_module, opts} -> Pax.Adapter.init(adapter_module, module, opts)
      {adapter_module, callback_module, opts} -> Pax.Adapter.init(adapter_module, callback_module, opts)
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/1"
    end
  end

  def merge_adapter_config(nil, _config, _socket), do: nil

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
    adapter_config_spec = init_adapter_config_spec(adapter)
    plugins_config_spec = init_plugins_config_spec(plugins)

    config_spec
    |> Map.put(:adapter, adapter_config_spec)
    |> Map.put(:plugins, plugins_config_spec)
  end

  defp init_adapter_config_spec(nil), do: %{}

  defp init_adapter_config_spec(adapter) do
    Pax.Adapter.config_spec(adapter)
  end

  defp init_plugins_config_spec(plugins) do
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

  defp get_module_config(module, socket) do
    case module.pax_config(socket) do
      config when is_map(config) or is_list(config) -> config
      _ -> raise ArgumentError, "invalid config returned from #{inspect(module)}.pax_config/1"
    end
  end

  # Global handle_params init helpers

  def assign_action(socket) do
    assign_pax(socket, :action, init_action(socket))
  end

  def init_action(socket) do
    # Action is derived from the router, and could be anything
    socket.assigns.live_action
  end

  def assign_path(socket, uri) do
    assign_pax(socket, :path, init_path(uri))
  end

  def init_path(uri) do
    # Parse the URI of the current request and Extract just the path and query from the URL.
    # TODO: Determine what happens when a very large URL is passed in, especially memory of the LV process.
    #       Bandit defaults to 10k request lines for http1, 50k headers for http2, which will include the `:path`
    #       pseudo-header.
    url = URI.parse(uri)
    %URI{path: url.path, query: url.query}
  end

  def assign_id_fields(socket) do
    assign_pax(socket, :id_fields, init_id_fields(socket))
  end

  def init_id_fields(socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    case Pax.Config.fetch(config, :id_fields, [socket]) do
      {:ok, id_fields} -> id_fields
      :error -> init_adapter_id_fields(adapter)
    end
  end

  defp init_adapter_id_fields(nil) do
    Pax.Interface.Config.default_id_fields()
  end

  defp init_adapter_id_fields(adapter) do
    case Pax.Adapter.id_fields(adapter) do
      nil -> Pax.Interface.Config.default_id_fields()
      fields -> fields
    end
  end

  def assign_fields(socket) do
    assign_pax(socket, :fields, init_fields(socket))
  end

  def init_fields(socket) do
    %{config: config, adapter: adapter, action: action} = socket.assigns.pax
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
      :error -> get_adapter_default_fields(adapter)
    end
  end

  defp get_adapter_default_fields(nil), do: []

  defp get_adapter_default_fields(adapter) do
    Pax.Adapter.default_fields(adapter)
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

  defp maybe_set_first_field_linked([], _config, _socket), do: []

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

  def assign_singular_name(socket) do
    assign_pax(socket, :singular_name, init_singular_name(socket))
  end

  def init_singular_name(socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    case Config.fetch(config, :singular_name, [socket]) do
      {:ok, value} -> value
      :error -> init_adapter_singular_name(adapter)
    end
  end

  defp init_adapter_singular_name(nil), do: "Object"

  defp init_adapter_singular_name(adapter) do
    case Pax.Adapter.singular_name(adapter) do
      nil -> "Object"
      name -> name
    end
  end

  def assign_plural_name(socket) do
    assign_pax(socket, :plural_name, init_plural_name(socket))
  end

  def init_plural_name(socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    case Config.fetch(config, :plural_name, [socket]) do
      {:ok, value} -> value
      :error -> init_adapter_plural_name(adapter)
    end
  end

  defp init_adapter_plural_name(nil), do: "Objects"

  defp init_adapter_plural_name(adapter) do
    case Pax.Adapter.plural_name(adapter) do
      nil -> "Objects"
      name -> name
    end
  end

  def assign_index_path(socket, params) do
    assign_pax(socket, :index_path, init_index_path(params, socket))
  end

  def init_index_path(params, socket) do
    %{config: config, action: action, path: path} = socket.assigns.pax

    case Config.fetch(config, :index_path, [socket]) do
      {:ok, value} ->
        case action do
          :index ->
            path

          _ ->
            index_query = Map.get(params, "index_query")
            Pax.Util.URI.append_query(value, Pax.Util.URI.decode_query_string(index_query))
        end

      :error ->
        nil
    end
  end

  def assign_new_path(socket, params) do
    assign_pax(socket, :new_path, init_new_path(params, socket))
  end

  def init_new_path(params, socket) do
    %{config: config, action: action, path: path} = socket.assigns.pax

    case Config.fetch(config, :new_path, [socket]) do
      {:ok, value} ->
        case action do
          :index ->
            Pax.Util.URI.with_params(value, index_query: Pax.Util.URI.encode_query_string(path))

          _ ->
            index_query = Map.get(params, "index_query")
            Pax.Util.URI.with_params(value, index_query: index_query)
        end

      :error ->
        nil
    end
  end

  def assign_default_scope(socket) do
    default_scope = init_default_scope(socket)

    socket
    |> assign_pax(:default_scope, default_scope)
    |> assign_pax(:scope, default_scope)
  end

  def init_default_scope(socket) do
    %{config: config} = socket.assigns.pax

    case Pax.Config.fetch(config, :default_scope, [socket]) do
      {:ok, value} -> Map.new(value)
      :error -> %{}
    end
  end

  # Detail handle_params init helpers

  def assign_object(socket, params, uri) do
    assign_pax(socket, :object, init_object(params, uri, socket))
  end

  def init_object(params, uri, socket) do
    %{module: module, adapter: adapter, action: action, scope: scope} = socket.assigns.pax

    case action do
      :new -> init_new_object(module, adapter, socket)
      action when action in [:show, :edit] -> init_get_object(module, adapter, scope, params, uri, socket)
      _ -> nil
    end
  end

  defp init_new_object(module, adapter, socket) do
    case module.new_object(socket) do
      :not_implemented -> init_adapter_new_object(adapter, socket)
      object when is_map(object) -> object
      other -> raise "new_object/1 must return an object (map), got: #{inspect(other)}"
    end
  end

  defp init_adapter_new_object(nil, _socket) do
    raise "Could not create a new object for the page. You must either define " <>
            "a `new_object/1` callback, or configure a Pax.Adapter."
  end

  defp init_adapter_new_object(adapter, socket) do
    Pax.Adapter.new_object(adapter, socket)
  end

  defp init_get_object(module, adapter, scope, params, uri, socket) do
    lookup = init_lookup(params, uri, socket)

    case module.get_object(lookup, scope, socket) do
      :not_implemented -> init_adapter_get_object(adapter, lookup, scope, socket)
      object when is_map(object) -> object
      other -> raise "get_object/3 must return an object (map), got: #{inspect(other)}"
    end
  end

  def init_lookup(params, uri, socket) do
    %{config: config} = socket.assigns.pax

    # Check if the user has defined a `:lookup` config option, which can only be a function, and call it.
    # Otherwise, construct a lookup map using config, the adapter, and some sensible defaults.
    case Config.fetch(config, :lookup, [params, uri, socket]) do
      {:ok, value} -> value
      :error -> construct_lookup_map(params, socket)
    end
  end

  defp init_adapter_get_object(nil, _lookup, _scope, _socket) do
    raise "Could not get the object for the page. You must either define " <>
            "a `get_object/3` callback, or configure a Pax.Adapter."
  end

  defp init_adapter_get_object(adapter, lookup, scope, socket) do
    Pax.Adapter.get_object(adapter, lookup, scope, socket)
  end

  defp construct_lookup_map(params, socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    # Get the list of params, which could be individually specified as `lookup_params` or a list of strings from
    # `lookup_glob` depending on how they configured their router.
    param_values = lookup_params(params, socket)

    # Get the list of id fields for the object, which should be a list of atoms. If none are defined in the config,
    # then use the adapter to figure out a default. If the adapter can't help then just use a default.
    id_fields =
      case Config.fetch(config, :id_fields, [socket]) do
        {:ok, value} ->
          value

        :error ->
          if Pax.Adapter.adapter?(adapter) do
            case Pax.Adapter.id_fields(adapter) do
              nil -> Pax.Interface.Config.default_id_fields()
              fields -> fields
            end
          else
            Pax.Interface.Config.default_id_fields()
          end
      end

    # Make sure that the number of lookup params matches the number of id fields
    if length(param_values) != length(id_fields) do
      raise ArgumentError, "The number of params must match the number of id_fields"
    end

    # Zip the id fields with the param values to create a map of id field -> param value
    Enum.zip_reduce(id_fields, param_values, %{}, fn id_field, param_value, acc ->
      if not is_atom(id_field) do
        raise ArgumentError, "id_fields must be a list of atoms, got #{inspect(id_field)}"
      end

      Map.put(acc, id_field, param_value)
    end)
  end

  defp lookup_params(params, socket) do
    %{config: config} = socket.assigns.pax

    lookup_params = Config.get(config, :lookup_params, [socket])
    lookup_glob = Config.get(config, :lookup_glob, [socket])

    cond do
      lookup_params != nil and lookup_glob != nil ->
        raise ArgumentError, "You can't define both :lookup_params and :lookup_glob in the config"

      lookup_params != nil ->
        fetch_lookup_params(lookup_params, params)

      lookup_glob != nil ->
        fetch_lookup_glob(lookup_glob, params)

      true ->
        Pax.Interface.Config.default_lookup_params() |> fetch_lookup_params(params)
    end
  end

  defp fetch_lookup_params(lookup_params, params) do
    for lookup_param <- lookup_params do
      case Map.fetch(params, to_string(lookup_param)) do
        {:ok, value} -> value
        :error -> raise ArgumentError, "Missing param: #{lookup_param}"
      end
    end
  end

  defp fetch_lookup_glob(lookup_glob, params) do
    case Map.fetch(params, lookup_glob) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "Missing param: #{lookup_glob}"
    end
  end

  def assign_object_name(socket) do
    assign_pax(socket, :object_name, init_object_name(socket))
  end

  def init_object_name(socket) do
    %{config: config, adapter: adapter, object: object} = socket.assigns.pax

    if object do
      case Config.fetch(config, :object_name, [object, socket]) do
        {:ok, nil} -> init_adapter_object_name(adapter, object)
        {:ok, value} -> value
        :error -> init_adapter_object_name(adapter, object)
      end
    else
      "Object"
    end
  end

  defp init_adapter_object_name(nil, _object), do: "Object"

  defp init_adapter_object_name(adapter, object) do
    case Pax.Adapter.object_name(adapter, object) do
      nil -> "Object"
      name -> name
    end
  end

  def assign_show_path(socket) do
    %{action: action} = socket.assigns.pax

    if action in [:show, :edit] do
      assign_pax(socket, :show_path, init_show_path(socket))
    else
      socket
    end
  end

  def init_show_path(socket) do
    %{config: config, object: object, index_query: index_query} = socket.assigns.pax

    case Config.fetch(config, :show_path, [object, socket]) do
      {:ok, value} -> Pax.Util.URI.with_params(value, index_query: index_query)
      :error -> nil
    end
  end

  def assign_edit_path(socket) do
    %{action: action} = socket.assigns.pax

    if action in [:show, :edit] do
      assign_pax(socket, :edit_path, init_edit_path(socket))
    else
      socket
    end
  end

  def init_edit_path(socket) do
    %{config: config, object: object, index_query: index_query} = socket.assigns.pax

    case Config.fetch(config, :edit_path, [object, socket]) do
      {:ok, value} -> Pax.Util.URI.with_params(value, index_query: index_query)
      :error -> nil
    end
  end
end
