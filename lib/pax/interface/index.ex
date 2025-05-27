defmodule Pax.Interface.Index do
  @moduledoc false
  import Pax.Interface.Context
  require Logger
  alias Phoenix.LiveView.LiveStream

  def handle_params(_params, _uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
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
  # very much since introduced, and all changes up to this point would not have affected our usage of `LiveStream`.
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
  # `@streams.objects`
  #
  # This is left commented out as a fallback to streaming in case something changes in LiveView
  #
  # defp stream_objects_directly(socket) do
  #   %{id_fields: id_fields} = socket.assigns.pax
  #
  #   opts = [
  #     reset: true,
  #     dom_id: fn object -> object_dom_id(object, id_fields) end
  #   ]
  #
  #   Phoenix.LiveView.stream(socket, :pax_objects, init_objects(socket), opts)
  # end

  # Assign the objects to the socket.
  #
  # This is left commented out as a fallback to streaming in case something changes in LiveView
  #
  # defp assign_objects(socket) do
  #   %{id_fields: id_fields} = socket.assigns.pax
  #
  #   objects_with_dom_ids =
  #     for object <- init_objects(socket) do
  #       {object_dom_id(object, id_fields), object}
  #     end
  #
  #   assign_pax(socket, :objects, objects_with_dom_ids)
  # end

  # Catch-all for all other events that we don't care about
  def handle_event(_event, _params, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.handle_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
  end

  # Catch-all for all other info messages that we don't care about
  def handle_info(_msg, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.handle_info(#{inspect(msg)})")
    {:cont, socket}
  end

  # Catch-all for all other async results that we don't care about
  def handle_async(_name, _return, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.handle_async(#{inspect(name)})")
    {:cont, socket}
  end

  # Do things after rendering the live view, but this will not trigger a rerender.
  def after_render(socket) do
    case socket.assigns.pax.objects do
      %LiveStream{} = stream -> assign_pax(socket, :objects, LiveStream.prune(stream))
      _ -> socket
    end
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
