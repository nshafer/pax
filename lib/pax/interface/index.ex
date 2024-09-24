defmodule Pax.Interface.Index do
  @moduledoc false
  import Pax.Interface.Context
  alias Pax.Config
  require Logger

  def on_params(_params, _uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_params(#{inspect(params)}, #{inspect(uri)}")
    %{config: config, adapter: adapter, scope: scope} = socket.assigns.pax

    fields = init_fields(config, adapter, socket)
    object_count = Pax.Adapter.count_objects(adapter, scope)
    objects = Pax.Adapter.list_objects(adapter, scope)

    socket =
      socket
      |> assign_pax(:fields, fields)
      |> assign_pax(:object_count, object_count)
      |> assign_pax(:objects, objects)

    {:cont, socket}
  end

  # Catch-all for all other events that we don't care about
  def on_event(event, params, socket) do
    Logger.info("IGNORED: #{inspect(__MODULE__)}.on_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
  end

  defp init_fields(config, adapter, socket) do
    config
    |> get_fields(adapter, socket)
    |> init_fields_with_link(config, adapter, socket)
  end

  defp get_fields(config, adapter, socket) do
    case Config.fetch(config, :index_fields, [socket]) do
      {:ok, fields} -> fields
      :error -> Pax.Adapter.default_index_fields(adapter)
    end
  end

  defp init_fields_with_link(fields, config, adapter, socket) do
    # Iterate through the list of fieldspecs, initializing them with Pax.Field.init, then for any field
    # with `link: true` set it to the proper callback (`config.show_path` or `config.edit_path`). If there
    # are no fields with a link set, we'll make the first field a link if there is a config set, first
    # `config.show_path`, then `config.edit_path`.

    # Check if the config has a show_path or edit_path set, but don't call the functions yet since we don't have
    # an object to pass to them in this scope.
    has_show_path = config[:show_path] != nil
    has_edit_path = config[:edit_path] != nil

    {fields, has_link} =
      for fieldspec <- fields, reduce: {[], false} do
        {fields, has_link} ->
          field =
            adapter
            |> Pax.Field.init(fieldspec)
            |> resolve_field_link(config, socket, has_show_path, has_edit_path)

          {[field | fields], Map.has_key?(field.opts, :link) || has_link}
      end

    if has_link do
      Enum.reverse(fields)
    else
      fields
      |> Enum.reverse()
      |> maybe_set_first_field_linked(config, socket, has_show_path, has_edit_path)
    end
  end

  defp resolve_field_link(field, config, socket, has_show_path, has_edit_path) do
    case Map.get(field.opts, :link) do
      # Convert a `link: true` field into a function call to the proper callback, otherwise raise an error
      true ->
        cond do
          has_show_path -> Pax.Field.set_link(field, fn object -> Config.get(config, :show_path, [object, socket]) end)
          has_edit_path -> Pax.Field.set_link(field, fn object -> Config.get(config, :edit_path, [object, socket]) end)
          true -> raise "You must configure either :show_path or :edit_path to use link: true"
        end

      # Otherwise just return the field as is if there is an explicit link set (callback, url, etc) or not.
      _link ->
        field
    end
  end

  defp maybe_set_first_field_linked(fields, _config, _socket, false, false) do
    fields
  end

  defp maybe_set_first_field_linked(fields, config, socket, has_show_path, has_edit_path) do
    [first_field | rest] = fields

    first_field =
      cond do
        has_show_path ->
          Pax.Field.set_link(first_field, fn object -> Config.get(config, :show_path, [object, socket]) end)

        has_edit_path ->
          Pax.Field.set_link(first_field, fn object -> Config.get(config, :edit_path, [object, socket]) end)

        true ->
          first_field
      end

    [first_field | rest]
  end
end
