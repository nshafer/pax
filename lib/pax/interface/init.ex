defmodule Pax.Interface.Init do
  @moduledoc false

  def init_adapter(module, socket) do
    case module.adapter(socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.adapter/1"
    end
  end

  def init_singular_name(module, adapter, socket) do
    init_optional_callback(module, :singular_name, [socket], fn ->
      Pax.Adapter.singular_name(adapter)
    end)
  end

  def init_plural_name(module, adapter, socket) do
    init_optional_callback(module, :plural_name, [socket], fn ->
      Pax.Adapter.plural_name(adapter)
    end)
  end

  def init_object_name(_module, _adapter, _socket, nil), do: "Object"

  def init_object_name(module, adapter, socket, object) do
    init_optional_callback(module, :object_name, [object, socket], fn ->
      Pax.Adapter.object_name(adapter, object)
    end)
  end

  def init_index_path(module, socket) do
    init_optional_callback(module, :index_path, [socket], fn -> nil end)
  end

  def init_new_path(module, socket) do
    init_optional_callback(module, :new_path, [socket], fn -> nil end)
  end

  def init_show_path(module, object, socket) do
    init_optional_callback(module, :show_path, [object, socket], fn -> nil end)
  end

  def init_edit_path(module, object, socket) do
    init_optional_callback(module, :edit_path, [object, socket], fn -> nil end)
  end

  # If the module defines a callback that will take the args, call it. If it isn't defined, or
  # returns null, run the fallback instead.
  defp init_optional_callback(module, callback, args, fallback) do
    if function_exported?(module, callback, length(args)) do
      case apply(module, callback, args) do
        nil -> fallback.()
        value -> value
      end
    else
      fallback.()
    end
  end
end
