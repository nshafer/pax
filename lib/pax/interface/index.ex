defmodule Pax.Interface.Index do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]
  import Pax.Interface.Util
  require Logger

  def on_handle_params(module, adapter, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_params(#{inspect(module)}, #{inspect(params)}, #{inspect(uri)}")
    fields = init_fields(module, adapter, socket)

    socket =
      socket
      |> assign_pax(:fields, fields)
      |> assign(:objects, Pax.Adapter.list_objects(adapter, params, uri, socket))

    {:cont, socket}
  end

  # Catch-all for all other events that we don't care about
  def on_handle_event(_module, _adapter, event, params, socket) do
    Logger.info("IGNORED: #{inspect(__MODULE__)}.on_handle_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
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
