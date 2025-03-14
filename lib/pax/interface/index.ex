defmodule Pax.Interface.Index do
  @moduledoc false
  import Pax.Interface.Context
  require Logger
  alias Phoenix.LiveView.LiveStream
  alias Pax.Config

  def on_params(_params, _uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_params(#{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign_pax(:fields, init_fields(socket))
      |> assign_pax(:object_count, init_object_count(socket))
      |> stream_objects()

    # Fallback implementations
    # |> stream_objects_directly()
    # |> assign_objects()

    {:cont, socket}
  end

  # The following is roughly equivalent to calling the public stream function, such as:
  #
  #     stream(socket, :pax_objects, objects, opts)
  #
  # However, that will put the stream in the @streams assign. This is technically fine, but I don't like it.
  #
  # 1. It requires passing around the @streams assign, which is meh.
  # 2. This makes the key `:pax_objects` show up in the `@streams` assign where users will see it. Not horrible, but
  #    not great either.
  # 3. The `stream*` functions in Phoenix.LiveView are basically just wrappers around `LiveStream`, which does all of
  #    the work for streams.
  #
  # So instead, we're going to put a `%LiveStream{}` directly in the `@pax.objects` assign. This is a bit cleaner, and
  # makes it easier to access the stream in the template.
  #
  # This is a risk, as LiveStream is `@moduledoc false` so considered internal API. However, streams haven't changed
  # very much since introduced, and all changes would have been transparent to our usage of `LiveStream`.
  #
  # If something does change in LiveView, which breaks our code, then we can fall back to `assign_objects` above, taking
  # the memory hit, or we can revert to using the `stream*` functions in Phoenix.LiveView.
  defp stream_objects(socket) do
    %{id_fields: id_fields} = socket.assigns.pax

    opts = [
      reset: true,
      dom_id: fn object -> object_dom_id(object, id_fields) end
    ]

    objects_stream =
      LiveStream.new(:objects, "pax_objects", init_objects(socket), opts)
      |> LiveStream.reset()

    assign_pax(socket, :objects, objects_stream)
  end

  defp object_dom_id(object, id_fields) do
    ids = Enum.map(id_fields, &Map.get(object, &1))

    "pax-object-#{Enum.join(ids, "-")}"
  end

  # Stream objects using the public `stream*` functions in Phoenix.LiveView. This puts the objects in
  # This is left commented out as a fallback to streaming in case something changes in LiveView
  # `@streams.objects`
  # defp stream_objects_directly(socket) do
  #   %{id_fields: id_fields} = socket.assigns.pax

  #   opts = [
  #     reset: true,
  #     dom_id: fn object -> object_dom_id(object, id_fields) end
  #   ]

  #   Phoenix.LiveView.stream(socket, :pax_objects, init_objects(socket), opts)
  # end

  # Assign the objects to the socket.
  # This is left commented out as a fallback to streaming in case something changes in LiveView
  # defp assign_objects(socket) do
  #   %{id_fields: id_fields} = socket.assigns.pax

  #   objects_with_dom_ids =
  #     for object <- init_objects(socket) do
  #       {object_dom_id(object, id_fields), object}
  #     end

  #   assign_pax(socket, :objects, objects_with_dom_ids)
  # end

  # Catch-all for all other events that we don't care about
  def on_event(_event, _params, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.on_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
  end

  # Catch-all for all other info messages that we don't care about
  def on_info(_msg, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.on_info(#{inspect(msg)})")
    {:cont, socket}
  end

  # Catch-all for all other async results that we don't care about
  def on_async(_name, _return, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.on_async(#{inspect(name)})")
    {:cont, socket}
  end

  # Do things after rendering the live view, but this will not trigger a rerender.
  def after_render(socket) do
    Logger.debug("#{inspect(__MODULE__)}.after_render()")

    case socket.assigns.pax.objects do
      %LiveStream{} = stream ->
        Logger.debug("Resetting objects stream")
        assign_pax(socket, :objects, Phoenix.LiveView.LiveStream.prune(stream))

      _ ->
        Logger.debug("No stream to reset")
        socket
    end
  end

  defp init_fields(socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax
    fields = get_fields(socket)

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
            |> resolve_field_link(has_show_path, has_edit_path, socket)

          {[field | fields], Map.has_key?(field.opts, :link) || has_link}
      end

    if has_link do
      Enum.reverse(fields)
    else
      fields
      |> Enum.reverse()
      |> maybe_set_first_field_linked(has_show_path, has_edit_path, socket)
    end
  end

  defp get_fields(socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    case Config.fetch(config, :index_fields, [socket]) do
      {:ok, fields} -> fields
      :error -> Pax.Adapter.default_index_fields(adapter)
    end
  end

  defp resolve_field_link(field, has_show_path, has_edit_path, socket) do
    %{config: config} = socket.assigns.pax

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

  defp maybe_set_first_field_linked(fields, false, false, _socket) do
    fields
  end

  defp maybe_set_first_field_linked(fields, has_show_path, has_edit_path, socket) do
    %{config: config} = socket.assigns.pax
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

  defp init_object_count(socket) do
    %{adapter: adapter, scope: scope} = socket.assigns.pax
    Pax.Adapter.count_objects(adapter, scope)
  end

  defp init_objects(socket) do
    %{adapter: adapter, scope: scope} = socket.assigns.pax
    Pax.Adapter.list_objects(adapter, scope)
  end
end
