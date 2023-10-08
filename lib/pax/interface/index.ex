defmodule Pax.Interface.Index do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]
  import Pax.Interface.Util
  require Logger

  def on_handle_params(module, adapter, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")
    fields = init_fields(module, adapter, socket)
    objects = Pax.Adapter.list_objects(adapter, params, uri, socket)

    socket =
      socket
      |> assign_pax(:fields, fields)
      |> assign(:objects, objects)

    {:cont, socket}
  end

  # Catch-all for all other events that we don't care about
  def on_handle_event(_module, _adapter, event, params, socket) do
    Logger.info("IGNORED: #{inspect(__MODULE__)}.on_handle_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
  end

  defp init_fields(module, adapter, socket) do
    get_fields(module, adapter, socket)
    |> init_fields_with_link(module, adapter, socket)
  end

  defp get_fields(module, adapter, socket) do
    case module.index_fields(socket) do
      fields when is_list(fields) -> fields
      nil -> Pax.Adapter.default_index_fields(adapter)
      _ -> raise ArgumentError, "Invalid fields returned from #{inspect(module)}.index_fields/1"
    end
  end

  defp init_fields_with_link(fields, module, adapter, socket) do
    # Iterate through the list of fieldspecs, initializing them with Pax.Field.init, then for any field
    # with `link: true` set it to the proper callback (show_path/1) or (edit_path/1). If there
    # are no fields with a link set, we'll make the first field a link if there is a callback defined, first
    # show_path/1, then edit_path/1.
    has_show_path = function_exported?(module, :show_path, 2)
    has_edit_path = function_exported?(module, :edit_path, 2)

    {fields, has_link} =
      for fieldspec <- fields, reduce: {[], false} do
        {fields, has_link} ->
          field =
            Pax.Field.init(adapter, fieldspec)
            |> resolve_field_link(module, socket, has_show_path, has_edit_path)

          {[field | fields], Map.has_key?(field.opts, :link) || has_link}
      end

    if has_link do
      Enum.reverse(fields)
    else
      Enum.reverse(fields)
      |> maybe_set_first_field_linked(module, socket, has_show_path, has_edit_path)
    end
  end

  defp resolve_field_link(field, module, socket, has_show_path, has_edit_path) do
    case Map.get(field.opts, :link) do
      true ->
        cond do
          has_show_path -> Pax.Field.set_link(field, fn object -> module.show_path(socket, object) end)
          has_edit_path -> Pax.Field.set_link(field, fn object -> module.edit_path(socket, object) end)
          true -> raise "You must implement either show_path/2 or edit_path/2 to use link: true"
        end

      _link ->
        field
    end
  end

  defp maybe_set_first_field_linked(fields, _module, _socket, false, false) do
    fields
  end

  defp maybe_set_first_field_linked(fields, module, socket, has_show_path, has_edit_path) do
    [first_field | rest] = fields

    first_field =
      cond do
        has_show_path -> Pax.Field.set_link(first_field, fn object -> module.show_path(socket, object) end)
        has_edit_path -> Pax.Field.set_link(first_field, fn object -> module.edit_path(socket, object) end)
        true -> first_field
      end

    [first_field | rest]
  end
end
