defmodule Pax.Interface.Index do
  @moduledoc false
  import Pax.Interface
  require Logger
  alias Phoenix.LiveView.LiveStream

  @callback count_objects(scope :: map(), socket :: Phoenix.LiveView.Socket.t()) :: non_neg_integer()
  @callback list_objects(scope :: map(), socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Interface.object()]

  @optional_callbacks [
    count_objects: 2,
    list_objects: 2
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Interface.Index

      def count_objects(_scope, _socket), do: :not_implemented
      def list_objects(_scope, _socket), do: :not_implemented

      defoverridable count_objects: 2, list_objects: 2
    end
  end

  def handle_params(_params, _uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign_object_count()
      |> stream_objects()

    # Fallback implementations
    # |> stream_objects_directly()
    # |> assign_objects()

    {:cont, socket}
  end

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
    clear_objects_stream(socket)
  end

  # Object count

  defp assign_object_count(socket) do
    assign_pax(socket, :object_count, init_object_count(socket))
  end

  defp init_object_count(socket) do
    %{module: module, adapter: adapter, scope: scope} = socket.assigns.pax

    case module.count_objects(scope, socket) do
      :not_implemented -> init_adapter_count_objects(adapter, scope)
      count when is_integer(count) and count >= 0 -> count
      other -> raise "count_objects/2 must return a non-negative integer, got: #{inspect(other)}"
    end
  end

  defp init_adapter_count_objects(nil, _scope) do
    raise "Could not get a total count of objects for the page. You must either define " <>
            "a `count_objects/2` callback or configure a Pax.Adapter."
  end

  defp init_adapter_count_objects(adapter, scope) do
    Pax.Adapter.count_objects(adapter, scope)
  end

  # Object streaming

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

  def clear_objects_stream(socket) do
    case socket.assigns.pax.objects do
      %LiveStream{} = stream -> assign_pax(socket, :objects, LiveStream.prune(stream))
      _ -> socket
    end
  end

  # Stream objects using the public `stream*` functions in Phoenix.LiveView. This puts the objects in
  # `@streams.objects`
  #
  # This is unused and left as a fallback to streaming in case something changes in LiveView

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
  # This is unused and left as a fallback to streaming in case something changes in LiveView

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

  defp init_objects(socket) do
    %{module: module, adapter: adapter, scope: scope} = socket.assigns.pax

    case module.list_objects(scope, socket) do
      :not_implemented -> init_adapter_list_objects(adapter, scope)
      objects when is_list(objects) -> objects
      other -> raise "list_objects/2 must return a list of objects, got: #{inspect(other)}"
    end
  end

  defp init_adapter_list_objects(nil, _scope) do
    raise "Could not list objects for the page. You must either define " <>
            "a `list_objects/2` callback, or configure a Pax.Adapter."
  end

  defp init_adapter_list_objects(adapter, scope) do
    Pax.Adapter.list_objects(adapter, scope)
  end
end
