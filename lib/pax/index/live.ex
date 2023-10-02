defmodule Pax.Index.Live do
  @moduledoc """
  Implements a live view for an index page, built on top of Pax.LiveView.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView
  import Pax.LiveView

  @callback pax_fields(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Field.fieldspec()] | nil

  defmacro __using__(_opts) do
    quote do
      # IO.puts("Pax.Index.Live.__using__ for #{inspect(__MODULE__)}")
      use Pax.LiveView
      @behaviour Pax.Index.Live
      @behaviour Pax.Field.Callback

      defdelegate pax_internal_init(module, socket), to: Pax.Index.Live

      def pax_fields(_socket), do: nil

      defoverridable pax_fields: 1
    end
  end

  def pax_internal_init(module, socket) do
    # IO.puts("#{inspect(__MODULE__)}.pax_internal_init(#{inspect(module)})")
    adapter = socket.assigns.pax.adapter
    fields = init_fields(module, adapter, socket)

    socket =
      socket
      |> assign_pax(:fields, fields)
      |> attach_hook(:pax_handle_params, :handle_params, fn params, uri, socket ->
        on_handle_params(module, fields, params, uri, socket)
      end)

    {:cont, socket}
  end

  def on_handle_params(module, _fields, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")
    adapter = socket.assigns.pax.adapter

    socket =
      socket
      |> assign_pax(:uri, URI.parse(uri))
      |> assign(:objects, Pax.Adapter.list_objects(adapter, params, uri, socket))

    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  defp init_fields(module, adapter, socket) do
    get_fields(module, adapter, socket)
    |> set_link_field_if_link_callback(module)
    |> Enum.map(&Pax.Field.init(module, adapter, &1))
  end

  defp get_fields(module, adapter, socket) do
    case module.pax_fields(socket) do
      fields when is_list(fields) -> fields
      nil -> Pax.Adapter.default_index_fields(adapter)
      _ -> raise ArgumentError, "Invalid fields returned from #{inspect(module)}.pax_fields/1"
    end
  end

  defp set_link_field_if_link_callback(fields, module) do
    # If a pax_field_link callback is defined, set the link field to the first field unless at least one field is
    # already set to link. This is so that if no fields are defined to link, but pax_field_link() is provided,
    # then make the first field linked by default.
    if function_exported?(module, :pax_field_link, 1) do
      fields |> Pax.Field.Util.maybe_set_default_link_field()
    else
      fields
    end
  end
end
